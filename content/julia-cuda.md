+++
title = "用 Julia 编写 CUDA 程序"
date = 2022-01-22
[taxonomies]
tags = ["programming", "julia"]
+++

CUDA 本身是一个 C 库，而 CUDA kernel 则需要使用扩展的 C/C++ 语法。但 [CUDA.jl] 让 Julia CUDA 编程成为可能。然而虽然 CUDA.jl 实现了绝大多数 CUDA 的功能，但其文档仍很不完善。本文补充了一些常见 CUDA 功能在 Julia 中的写法。本文假设读者预先具有 Julia，CUDA，以及 CUDA.jl 的基本知识。

[CUDA.jl](https://cuda.juliagpu.org/stable/)

<!-- more -->

# Kernel

Julia 的基本语法本身与 C 类似，可以类似地编写 CUDA kernel 而无需指定 `__device__` 或 `__global__` 关键字。而且其运行时编译的特性也使得函数自动成为泛型。然而需要注意 Julia 在部分数值处理的地方与 C 行为不同。例如，浮点数转换为整数时 Julia 不会自动取整，而是会在发生舍入时报错。假设 `a::CuDeviceArray{Int, 1}`，那么下面的代码

```julia
a[idx] = c / d
```

很可能会报错。正确的写法是 `a[idx] = trunc(c / d)` 或 `a[idx] = c ÷ d`。

令人头疼的是 kernel 中的异常不会以正常的 Julia Exception 的形式抛出，所以没有具体发生错误的行号供参考，所以调试这类问题会比较麻烦。好在 kernel 里的代码只要不带 `threadIdx()` 这样的函数，就同样可以跑在 CPU 上。所以可以让代码在 CPU 上通过测试之后再去 GPU 上跑。

Julia 为 kernel 生成的类型信息，IR，PTX 代码可以通过 `CUDA.coda_warntype` 等函数找到。

<details>
<summary>例子</summary>

```
julia> CUDA.code_warntype(add!, (CuDeviceVector{Int32, 1},CuDeviceVector{Int32, 1}))
MethodInstance for add!(::CuDeviceVector{Int32, 1}, ::CuDeviceVector{Int32, 1})
  from add!(a, b) in Main at /home/pgw/my/cuda_julia_test/main.jl:18
Arguments
  #self#::Core.Const(add!)
  a::CuDeviceVector{Int32, 1}
  b::CuDeviceVector{Int32, 1}
Locals
  i::Int64
Body::Nothing
1 ─ %1  = Main.threadIdx()::NamedTuple{(:x, :y, :z), Tuple{Int32, Int32, Int32}}
│   %2  = Base.getproperty(%1, :x)::Int32
│   %3  = Main.blockIdx()::NamedTuple{(:x, :y, :z), Tuple{Int32, Int32, Int32}}
│   %4  = Base.getproperty(%3, :x)::Int32
│   %5  = (%4 - 1)::Int64
│   %6  = Main.blockDim()::NamedTuple{(:x, :y, :z), Tuple{Int32, Int32, Int32}}
│   %7  = Base.getproperty(%6, :x)::Int32
│   %8  = (%5 * %7)::Int64
│         (i = %2 + %8)
│   %10 = (i <= Main.SIZE)::Bool
└──       goto #3 if not %10
2 ─ %12 = Base.getindex(a, i)::Int32
│   %13 = Base.getindex(b, i)::Int32
│   %14 = (%12 + %13)::Int32
└──       Base.setindex!(a, %14, i)
3 ┄       return Main.nothing
```

</details>

# 获取设备信息

有的 CUDA API 没有对应的 Julia 函数封装，于是我们需要手动调用 CUDA.cu 开头的函数绑定。但是需要注意 CUDA.jl 使用的是 [CUDA Driver API][driver] 而不是通常 CUDA 教程里使用的 Runtime API。例如，要查询设备信息应该使用 [cuDeviceGetAttribute]，可以像下面这样写函数进行封装：

[driver]: https://docs.nvidia.com/cuda/cuda-driver-api/index.html
[cuDeviceGetAttribute]: https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__DEVICE.html#group__CUDA__DEVICE_1g9c3e1414f0ad901d3278a4d6645fc266

```julia
function getMaxThreadsPerBlock()
    value = Ref{Cint}()
    CUDA.cuDeviceGetAttribute(value, CUDA.CU_DEVICE_ATTRIBUTE_MAX_THREADS_PER_BLOCK, 0)
    value[]
end

function getDeviceOverlap()
    value = Ref{Cint}()
    CUDA.cuDeviceGetAttribute(value, CUDA.CU_DEVICE_ATTRIBUTE_GPU_OVERLAP, 0)
    value[] == 1
end
```

# Pinned Memory

在 CUDA C 中可以使用 `cudaHostAlloc` 来代替 `malloc` 申请 Host 内存，这样的内存复制到 GPU 的速度更快。在 CUDA.jl 中有Mem.HostBuffer 类型可以辅助实现这一功能，但封装的不是很彻底，我们需要自行写一点代码来进行封装。

```julia
buffertype(::Type{<:Array}) = Mem.HostBuffer
buffertype(::Type{<:CuArray}) = Mem.DeviceBuffer
pointertype(T::Type{<:Array}) = Ptr{eltype(T)}
pointertype(T::Type{<:CuArray}) = CuPtr{eltype(T)}

function allocarray(T::Type, size)
    B = buffertype(T)
    E = eltype(T)
    P = pointertype(T)
    buf = Mem.alloc(B, size * sizeof(E))
    arr = unsafe_wrap(T, P(buf.ptr), size)
    arr, buf
end
```

使用的时候需要手动管理内存，使用 `arr, buf = allocarray(Array{Int}, N)` 来申请内存并创建 `Array` 数组，使用结束后使用 `Mem.free(buf)` 来释放内存。

```julia
# slower equivalent:
# arr = Array{Int}(undef, 10)
# arr_dev = CuArray{Int}(undef, 10)
arr, buf = allocarray(Array{Int}, 10)
arr_dev, buf_dev = allocarray(CuArray{Int}, 10)

copyto!(arr_dev, 1, arr, 2, 4) # arr_dev[1:4] = arr[2:5]

Mem.free(buf)
Mem.free(buf_dev)
```
