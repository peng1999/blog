+++
title = "Docker 搭建 RoboMaster RoboRTS 框架构建环境"
date = 2020-08-02
[taxonomies]
tags = ["programming", "cpp", "ros"]
+++

[RoboRTS] 框架用于大疆的 RoboMaster ICRA 人工智能挑战赛。其构建环境基于 [ROS]，
在非 Ubuntu/CentOS 的 Linux 机器上面安装较为困难。于是我们采用基于 docker 的构建方案。

<!-- more -->
Dockerfile 如下：

```dockerfile
FROM ros:kinetic-perception
COPY ./MVS-2.0.0_x86_64_20191126.deb /root/MVS-2.0.0_x86_64_20191126.deb
# 换源
RUN sed -i "s/archive.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    sed -i "s/security.ubuntu.com/mirrors.aliyun.com/g" /etc/apt/sources.list && \
    echo "deb http://mirrors.tuna.tsinghua.edu.cn/ros/ubuntu/ xenial main" > /etc/apt/sources.list.d/ros1-latest.list && \
    rm -Rf /var/lib/apt/lists/* && \
    apt update

# 安装必须软件
RUN apt-get install -y ros-kinetic-opencv3              \
                       ros-kinetic-cv-bridge            \
                       ros-kinetic-image-transport      \
                       ros-kinetic-stage-ros            \
                       ros-kinetic-map-server           \
                       ros-kinetic-laser-geometry       \
                       ros-kinetic-interactive-markers  \
                       ros-kinetic-tf                   \
                       ros-kinetic-pcl-*                \
                       ros-kinetic-libg2o               \
                       ros-kinetic-rplidar-ros          \
                       ros-kinetic-rviz                 \
                       ros-kinetic-librealsense2        \
                       protobuf-compiler                \
                       libprotobuf-dev                  \
                       libsuitesparse-dev               \
                       libgoogle-glog-dev &&            \
    dpkg -i /root/MVS-2.0.0_x86_64_20191126.deb &&      \
    rm /root/MVS-2.0.0_x86_64_20191126.deb &&           \
    apt-get clean &&                                    \
    mkdir -p /root/catkin_ws/src
```

运行 `docker build` 即可构建，其中 `roborts:1.0` 是镜像名。

```sh
docker build --network=host -t roborts:1.0 .
```

以下命令启动一个 docker 镜像并将当前目录挂载到镜像内的 `/root/catkin_ws/`。

```sh
docker run --rm -it --name ros-test -v $PWD/:/root/catkin_ws/ roborts:1.0
```

为了在 CLion 中编写该项目，我们需要在 Dockerfile 中再添加一层来安装 ssh 相关的包。

```dockerfile
RUN apt-get install -y ssh gdb rsync \
 && apt-get clean \
 && ( \
    echo 'LogLevel DEBUG2'; \
    echo 'PermitRootLogin yes'; \
    echo 'PasswordAuthentication yes'; \
    echo 'Subsystem sftp /usr/lib/openssh/sftp-server'; \
    echo 'PermitUserEnvironment yes'; \
  ) > /etc/ssh/sshd_config_clion \
 && mkdir -p /root/.ssh \
 && . /opt/ros/kinetic/setup.sh \
 && env > /root/.ssh/environment \
 && mkdir /run/sshd \
 && echo "root:password" | chpasswd

CMD /usr/sbin/sshd -D -e -f /etc/ssh/sshd_config_clion
```

用下面的命令启动 demon 容器。

```sh
docker run -d --cap-add sys_ptrace -p127.0.0.1:2222:22 --name clion_remote_env roborts:ssh
```

[RoboRTS]: https://github.com/RoboMaster/RoboRTS
[ROS]: https://www.ros.org/
