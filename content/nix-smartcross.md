+++
title = "用 Nix 管理交叉编译 Rust 项目的环境"
date = 2022-12-11
[taxonomies]
tags = ["rust", "nix"]
+++

SmartCross 项目的介绍见[这里][smartcross]。其中的控制器组件用 Rust 写成，需要编译到 aarch64 平台。我尝试写了一个 [Nix] 表达式来管理该项目的环境。

<!-- more -->

Nix 是很多东西的总称，包括

- 一个函数式编程语言 Nix 表达式
- 一个用 Nix Expression 进行打包的包管理系统 Nix，同时支持各种 Linux 和 MacOS，并允许多个版本的相同软件在系统中并存
- 一个世界上[最大][repo]的软件包仓库 Nixpkgs
- 一个操作系统 NixOS，使用 Nix 表达式来定义整个系统的软件和配置，并实现了原子更新和方便地系统回滚

同时 Nixpkgs 提供了一流的交叉编译支持。下面将编写描述构建环境的 Nix 表达式。

## CMake 项目的打包

首先该项目依赖的 [libubootenv] 没有在 nixpkgs 中打包，所以我们需要手动打包。只需要写一个 `libubootenv.nix` 文件，放在 `nix/` 目录下即可。Nixpkgs 的“genericBuild”机制可以处理 CMake 项目，基本只需要按模版简单填空即可。

```nix
{ lib, stdenv, fetchFromGitHub, cmake, zlib }:

stdenv.mkDerivation rec {
  pname = "libubootenv";
  version = "0.3.3";

  src = fetchFromGitHub {
    owner = "sbabic";
    repo = "libubootenv";
    rev = "v${version}";
    sha256 = "sha256-BQZp+/UbaEkXFioYPAoEA74kVN2sXfBY1+0vitKdfho=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ zlib ];

  # 这个选项是为了修复 pkg-config 给出路径错误的问题
  cmakeFlags = [
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
  ];

  meta = with lib; {
    description = "Generic library and tools to access and modify U-Boot environment from User Space";
    homepage    = "https://github.com/sbabic/libubootenv";
    license = licenses.mit;
  };
}
```

### 构建依赖

用 Nix 表达式写好一个包的定义之后，Nixpkgs 可以自动处理到不同平台的交叉编译。注意到如果包 `A` 依赖了包 `B`，`buildPlatform` 是编译时的平台，`hostPlatform` 是编译产物实际运行的平台，那么一般有以下两种情况

1. `hostPlatform B == hostPlatform A`
2. `hostPlatform B == buildPlatform A`

如果符合情况 1，例如 `B` 是 `A` 的运行时依赖，则需要将 `B` 放到 `A.buildInputs` 中去，如果符合情况 2，例如 `B` 是构建工具，则需要放到 `A.nativeBuildInputs` 中去。

## Rust 项目打包

### 使用 `buildRustPackage`

Rust 项目可以用 `nixpkgs.rustPlatform.buildRustPackage` 打包。同样是简单按模版填空即可。下面是 `nix/smartcross_controller.nix` 文件。

```nix
{ rustToolchain,
  makeRustPlatform, pkgconfig, protobuf, libubootenv, avahi, openssl, dbus, alsa-lib, zlib
}:

let rustPlatform = makeRustPlatform {
  rustc = rustToolchain;
  cargo = rustToolchain;
};

in rustPlatform.buildRustPackage rec {
  pname = "smartcross_controller";
  version = "0.1.0";

  src = ../.;
  cargoLock = {
    lockFile = ../Cargo.lock;
    outputHashes = {
      "camilladsp-1.0.1" = "sha256-XpQE+XVgQyVRg/NHCkPnpB/SGLChsUZucvL8x/ieKzI=";
      "libubootenv-rs-0.1.0" = "sha256-FRPnFjrlVS09W7MTjY0X8kwU04HZMcYxQAiVvEvKc08=";
      "rfkill-rs-0.1.0" = "sha256-uN58uzTeaQWLAEizNFZSldq2wkmlo8Si5xbQDyfYmYI=";
    };
  };

  nativeBuildInputs = [
    pkgconfig
    protobuf
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    libubootenv
    avahi
    openssl
    dbus.dev
    alsa-lib.dev
    zlib
  ];
}
```

基于可复现性的考虑，Rust 项目的 git 依赖需要全部填写哈希值。一些第三方库使用更高级的方法解决了这个问题。下面使用 [Crane] 来进行同样的打包。

### 使用 Crane 为 Rust 项目打包

Crane 比起 `buildRustPackage` 的另一个优点是提供了更细粒度的缓存。使用 `buildRustPackage`，每次更改项目代码后，重新编译都是一个 clean build，而使用 Crane，只要不更改依赖项，则不用重新编译 cargo 依赖。

遗憾的是，Crane 对交叉编译的支持没有 `buildRustPackage` 那么好。为了成功编译，我们需要给构建环境手动添加两个环境变量。其中一个环境变量名字中带有架构名称，使得一旦目标架构变化，我们就需要手动更改这个表达式。所幸我们不会频繁更换构建目标平台。

```nix
{ src, craneLib, target,
  stdenv, pkgconfig, protobuf, rustPlatform, libubootenv, avahi, openssl, dbus, alsa-lib, zlib
}:

craneLib.buildPackage {
  inherit src;

  nativeBuildInputs = [
    # ... 和前面相同
  ];

  buildInputs = [
    # ... 和前面相同
  ];

  # 任何不含有特殊意义的字段都将会直接变成构建环境中的环境变量
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "${stdenv.cc.targetPrefix}cc";
  CARGO_BUILD_TARGET = target;
}
```

这里我们没有指定 `src`，而是将其作为参数，稍后我们会具体给 `src` 赋值。

## 编写 Flake 表达式

接下来我们在项目根目录编写 `flake.nix`。这里面包含了关于构建环境所有的配置信息。

```nix
{
  # inputs 声明所有用到的库
  inputs = {
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = { self, rust-overlay, crane, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let # 下面将声明一系列变量（值）
        target = "aarch64-unknown-linux-gnu"; # 目标平台
        # pkgs 将成为 nixpkgs 特定目标平台的实例
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ]; # 为了自由选择 Rust 版本和组件，我们使用了 rust-overlay
          crossSystem = {
            config = target;
          };
        };
        # 选择最新的 stable Rust，带有 minimal 配置的组件
        rustToolchain = pkgs.pkgsBuildHost.rust-bin.stable.latest.minimal.override {
          targets = [ target ]; # 同时能够交叉编译到目标平台
        };
        # 将我们选择的 Rust 工具链应用到 Crane
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        # 辅助函数
        protoFilter = path: _type: builtins.match ".*proto$" path != null;
        # 一个函数，用来判断 path 是否是需要带入构建环境的文件
        protoOrCargo = path: type:
          (protoFilter path type) || (craneLib.filterCargoSources path type);
      in {
        # 这个 flake 可以生成的包
        packages = rec {
          default = smartcross_controller;

          # 构建 libubootenv
          libubootenv = pkgs.callPackage ./nix/libubootenv.nix {}; # 没有参数需要传递

          # 构建 smartcross_controller
          smartcross_controller = pkgs.callPackage ./nix/smartcross_controller.nix {
            # src 参数。构建 Rust 项目所需要的文件。无关的文件如 README 将不会被带入编译环境，也就不会因为修改而引发重新构建
            src = pkgs.lib.cleanSourceWith {
              src = ./.;
              filter = protoOrCargo;
            };

            # 语法糖，用于传递同名的参数
            inherit craneLib target libubootenv;
          };

          # 并不真正产生二进制产物，只是用于提供构建环境
          env = pkgs.callPackage (
            { mkShell, llvm, clang }:
            with smartcross_controller;
            mkShell {
              nativeBuildInputs = nativeBuildInputs ++ [ llvm clang ];
              inherit buildInputs CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER;
            }
          ) {};
        };
      });
}
```

接下来运行 `nix build '.#'` 即可开始 `smartcross_controller` 的构建。构建完成后，将留下 `result` 目录。

```
$ ls -ld result
lrwxrwxrwx 1 pgw pgw 97 Dec 11 17:17 result -> /nix/store/7zsmhixg5kf03ni0q0cc8i75c47kw8vr-smartcross_controller-aarch64-unknown-linux-gnu-0.1.0/
$ ls result/bin/
smartcross_controller*  updater*
$ file result/bin/smartcross_controller
result/bin/smartcross_controller: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /nix/store/0kbwlxnaxl0jly5szmgxqljrj3dxzyw8-glibc-aarch64-unknown-linux-gnu-2.35-163/lib/ld-linux-aarch64.so.1, for GNU/Linux 2.6.32, not stripped
```

使用 `nix build '.#libubootenv'` 可以单独构建 libubootenv，使用 `nix develop '.#env'` 可以进入一个 shell，这里面有全部定义好的构建环境。

```
$ nix develop '.#env'
[user@host SmartCrossCtrl]$ rustc --version
rustc 1.65.0 (897e37553 2022-11-02)
[user@host SmartCrossCtrl]$ cargo build
...(build success)
```
<!-- --- -->
<!-- # Footnote -->

[smartcross]: https://blog.t123yh.xyz:2/index.php/archives/1077
[Nix]: https://nixos.org/
[libubootenv]: https://github.com/sbabic/libubootenv
[Crane]: https://github.com/ipetkov/crane
[repo]: https://repology.org/repositories/statistics/nonunique

