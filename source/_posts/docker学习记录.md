---
title: docker学习记录
date: 2024-12-04 23:14:33
tags: [docker]
categories: [学习笔记]
excerpt: 记录学习docker的过程
index_img: /images/post/docker.png
---
# Docker学习记录

> Author: Punny
>
> Date: 2024/11/16

> 参考文档：https://yeasy.gitbook.io/docker_practice

+ 使用yum安装Docker

我的虚拟机中装的是CentOS注意一些要求：

> Docker 支持 64 位版本 CentOS 7/8，并且要求内核版本不低于 3.10。 CentOS 7 满足最低内核的要求，但由于内核版本比较低，部分功能（如 `overlay2` 存储层驱动）无法使用，并且部分功能可能不太稳定。

+ 卸载旧版

```bash
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
```

+ 安装依赖包

```bash
sudo yum install -y yum-utils
```

报错了，可能是镜像源的问题,没报错的可以直接忽略这一步

```bash
已加载插件：fastestmirror, langpacks
Loading mirror speeds from cached hostfile
Could not retrieve mirrorlist http://mirrorlist.centos.org/?release=7&arch=x86_64&repo=os&infra=stock error was
14: curl#6 - "Could not resolve host: mirrorlist.centos.org; 未知的错误"


 One of the configured repositories failed (未知),
 and yum doesn't have enough cached data to continue. At this point the only
 safe thing yum can do is fail. There are a few ways to work "fix" this:

     1. Contact the upstream for the repository and get them to fix the problem.

     2. Reconfigure the baseurl/etc. for the repository, to point to a working
        upstream. This is most often useful if you are using a newer
        distribution release than is supported by the repository (and the
        packages for the previous distribution release still work).

     3. Run the command with the repository temporarily disabled
            yum --disablerepo=<repoid> ...

     4. Disable the repository permanently, so yum won't use it by default. Yum
        will then just ignore the repository until you permanently enable it
        again or use --enablerepo for temporary usage:

            yum-config-manager --disable <repoid>
        or
            subscription-manager repos --disable=<repoid>

     5. Configure the failing repository to be skipped, if it is unavailable.
        Note that yum will try to contact the repo. when it runs most commands,
        so will have to try and fail each time (and thus. yum will be be much
        slower). If it is a very temporary problem though, this is often a nice
        compromise:

            yum-config-manager --save --setopt=<repoid>.skip_if_unavailable=true

Cannot find a valid baseurl for repo: base/7/x86_64

```

配置阿里云yum源

去到yum的仓库源目录

```bash
cd /etc/yum.repos.d
```

利用wget下载阿里云镜像源配置文件

```bash
wget http://mirrors.aliyun.com/repo/Centos-7.repo
```

备份原来的

```bash
mv CentOS-Base.repo CentOS-Base.repo.bak
```

用刚才下载的替换

```bash
mv Centos-7.repo CentOS-Base.repo
```

清除缓存更新

```bash
yum clean all
yum makecache
yum update
```

完成后再次安装依赖包

```bash
sudo yum install -y yum-utils
```

+ 切换docker的yum镜像源为阿里云仓库

```bash
sudo yum-config-manager \
    --add-repo \
    https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

sudo sed -i 's/download.docker.com/mirrors.aliyun.com\/docker-ce/g' /etc/yum.repos.d/docker-ce.repo
```

+ 正式安装docker

```bash
sudo yum install docker-ce docker-ce-cli containerd.io
```

+ 执行docker version验证是否安装完成

> Client: Docker Engine - Community
> Version:           26.1.4
> API version:       1.45
> Go version:        go1.21.11
> Git commit:        5650f9b
> Built:             Wed Jun  5 11:32:04 2024
> OS/Arch:           linux/amd64
> Context:           default
> Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?

显示docker版本信息，表示安装成功！

+ 启动docker

> Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?表示docker未启动

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

再次运行docker version即可看见更详细的内容

> Client: Docker Engine - Community
> Version:           26.1.4
> API version:       1.45
> Go version:        go1.21.11
> Git commit:        5650f9b
> Built:             Wed Jun  5 11:32:04 2024
> OS/Arch:           linux/amd64
> Context:           default
>
> Server: Docker Engine - Community
> Engine:
> Version:          26.1.4
> API version:      1.45 (minimum version 1.24)
> Go version:       go1.21.11
> Git commit:       de5c9cf
> Built:            Wed Jun  5 11:31:02 2024
> OS/Arch:          linux/amd64
> Experimental:     false
> containerd:
> Version:          1.6.33
> GitCommit:        d2d58213f83a351ca8f528a95fbd145f5654e957
> runc:
> Version:          1.1.12
> GitCommit:        v1.1.12-0-g51d5e94
> docker-init:
> Version:          0.19.0
> GitCommit:        de40ad0

+ 测试运行是否正常，使用hello world镜像

```bash
docker run --rm hello-world
```

报错了（没报错可以跳过）

> Unable to find image 'hello-world:latest' locally
> docker: Error response from daemon: Get "https://registry-1.docker.io/v2/": net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers).
> See 'docker run --help'.

原因是docker的镜像源默认是国外，最近应该是被墙了，国内很多也下架了

需要切换成国内有效的镜像源参考网站：https://status.1panel.top/status/docker

配置后可以执行docker pull 但是docker search还是不行，可以去下面的网站找docker镜像：https://docker.fxxk.dedyn.io/

新增配置文件

```bash
sudo vi /etc/docker/daemon.json
```

编辑内容

```json
{
    "registry-mirrors": [
        "https://docker.m.daocloud.io",
        "https://docker.1panel.live",
        "https://hub.rat.dev",
        "https://hub.xdark.top",
        "https://hub.littlediary.cn",
        "https://dockerpull.org",
        "https://hub.crdz.gq",
        "https://docker.unsee.tech",
        "https://registry.dockermirror.com",
        "https://docker.m.daocloud.io",
        "https://docker.ketches.cn",
        "https://docker.1ms.run"
    ]
}
```

esc退出编辑模式:wq!保存

重启docker

```bash
sudo service docker restart
```

再次执行

```bash
docker run --rm hello-world
```

成功运行

> Hello from Docker!
> This message shows that your installation appears to be working correctly.
>
> To generate this message, Docker took the following steps:
>
>   1. The Docker client contacted the Docker daemon.
>   2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
>      (amd64)
>   3. The Docker daemon created a new container from that image which runs the
>      executable that produces the output you are currently reading.
>   4. The Docker daemon streamed that output to the Docker client, which sent it
>      to your terminal.
>
> To try something more ambitious, you can run an Ubuntu container with:
>  $ docker run -it ubuntu bash
>
> Share images, automate workflows, and more with a free Docker ID:
>  https://hub.docker.com/
>
> For more examples and ideas, visit:
>  https://docs.docker.com/get-started/

+ docker的命令

docker search 搜索镜像

```bash
docker search mysql
```

docker pull 拉取镜像

也可以通过指定镜像的tag来拉取指定版本的镜像

没有指定tag默认为:latest

```bash
docker pull mysql #默认拉取最新版mysql:latest
docker pull mysql:5.7 #通过tag指定版本
```

docker images 查看镜像列表

> REPOSITORY    TAG       IMAGE ID              CREATED                SIZE
> mysql                latest    10db11fef9ce       4 weeks ago          602MB
> mysql                5.7         5107333e08a8    11 months ago     501MB
> hello-world       latest    d2c94e258dcb    18 months ago    13.3kB

可以查看镜像源、版本、镜像id、创建时间、和大小等信息

docker rmi 删除镜像

可以通过镜像名称、或者镜像id来删除镜像

```bash
docker rmi mysql #只删除mysql:latest
docker rmi mysql:5.7
docker rmi d2c94e258dcb #根据镜像id删除
```

docker run

> docker run命令用于指定一个镜像模板，并以此创建并启动一个容器
>
> 有很多参数来设置容器的一些配置

docker run [可选参数] 镜像名/镜像id

| 参数   | 作用                                                         | 示例                                  |
| ------ | ------------------------------------------------------------ | ------------------------------------- |
| --name | 为容器指定一个名称，便于管理。                               | docker run --name my-container ubuntu |
| -d     | 以 **后台模式** 运行容器。类似nohop                          | docker run -d nginx                   |
| -it    | 允许用户以交互模式运行容器，并附加到容器的终端（常用于调试）。<br />运行容器后会直接进入容器内部，可以通过exit命令退出容器并停止容器，Ctrl + P + Q可以退出容器但是不停容器 | docker run -it ubuntu /bin/bash       |
| --rm   | 在容器停止后自动删除容器。                                   | docker run --rm ubuntu                |
| -p     | 映射主机和容器的端口，用于访问容器内的服务。-p 主机端口:容器端口。也可以直接指定容器端口-p 容器端口 | docker run -p 8080:80 nginx           |
| -P     | 自动随机映射主机的可用端口到容器的暴露端口。                 | docker run -P nginx                   |

docker ps 列出正在运行的容器信息

docker ps -a 列出当前所有的容器的信息

docker rm 删除容器

docker start/restart 启动/重启一个已经存在的容器

docker stop 停止容器

docker kill 强制停止容器

docker stats 查看容器运行情况

+ 为什么使用docker run -d centos启动容器后，容器后马上停止

> 涉及到容器的生命周期和其关联的主进程相关的内容，后续再在这里探讨---2024/11/17

+ docker logs 查看容器的日志

> 涉及到的参数也有很多，后续再探讨---2024/11/17

查看容器内的进程信息 docker top

查看容器的元数据信息 docker inspect

以交互的形式进入当前正在运行的容器(会开启一个新的交互终端)docker exec -it 容器id/容器名称 需要执行的命令

比如进入mysql

```bash
docker exec -it mysql-container mysql -u root -p
```

进入容器正在运行的终端docker attach 容器id/容器名称

容器与本机文件直接的拷贝docker cp 

```bash
docker cp /path/on/host my_container:/path/in/container #将本机文件/path/on/host拷贝到容器my_container的/path/in/container路径下
docker cp my_container:/path/in/container /path/on/host #反过来就是把容器内的文件拷贝到本机
#不需要容器正在运行也可以进行拷贝，容器的路径格式为container-name:/path
```

+ 练习：利用docker部署tomcat

首先拉取镜像

```bash
docker pull tomcat
```

运行容器

```bash
docker run -d --name test-tomcat -p 8080:8080 tomcat #表示后台运行一个容器名称为‘test-tomcat’的tomcat镜像，并且将本机的8080端口映射到容器的8080端口
```

外部浏览器访问：虚拟机ip:8080 192.168.154.128:8080结果发现是404

进入容器内部查看原因

```bash
docker exec -it test-tomcat /bin/bash
```

利用ls命令查看文件内容可以看见熟习的tomcat文件结构

> bin           conf             lib      logs            NOTICE     RELEASE-NOTES  temp     webapps.dist
> BUILDING.txt  CONTRIBUTING.md  LICENSE  native-jni-lib  README.md  RUNNING.txt    webapps  work

发现webapps中是空的，原因是docker的tomcat镜像和原版相比有一些差异或者是精简

但是webapps.dist中是有的

> docs  examples  host-manager  manager  ROOT

利用命令将webapps.dist目录下的文件及其子目录下的文件都复制过去用cp 参数-r来实现

```bash
cp -r ./wabapps.dist/* ./wabapps
```

再次访问192.168.154.128:8080就成功了

+ 练习，利用docker部署elasticsearch，并限制内存

```bash
docker run -d --name elasticsearch \
  -p 9200:9200 -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "ES_JAVA_OPTS=-Xms128m -Xmx512m" \
  elasticsearch:7.6.2
```

注意：elasticsearch貌似没有latest的tag所以pull的时候要指定版本

访问： curl localhost:9200

> {
> "name" : "e66c5bc98b22",
> "cluster_name" : "docker-cluster",
> "cluster_uuid" : "8R4Q4fB_QjCMws3aJw6e6Q",
> "version" : {
>  "number" : "7.6.2",
>  "build_flavor" : "default",
>  "build_type" : "docker",
>  "build_hash" : "ef48eb35cf30adf4db14086e8aabd07ef6fb113f",
>  "build_date" : "2020-03-26T06:34:37.794943Z",
>  "build_snapshot" : false,
>  "lucene_version" : "8.4.0",
>  "minimum_wire_compatibility_version" : "6.8.0",
>  "minimum_index_compatibility_version" : "6.0.0-beta1"
> },
> "tagline" : "You Know, for Search"
> }

部署成功

+ 安装图形化界面portainer

  ```bash
  docker run -d -p 8088:9000 \
  --restart=always -v /var/run/docker.sock:/var/run/docker.sock --privileged=true portainer/portainer
  ```

  开放在8088端口

+ docker镜像对比操作系统镜像为什么这么小？

  > 操作系统镜像，比如linux镜像一般由内核(Kernel)还有Rootfs(root file system)所组成，而docker镜像与宿主机共享内核，镜像中只会包含rootfs，并且针对不同镜像也可以对rootfs进行适当的精简，所以docker镜像可以很小。
  >
  > 并且docker镜像采用分层结构，在pull的时候docker会分层下载镜像文件，如果发现有些层已经在本地下载过，那就可以直接复用，无需二次下载。

+ 数据挂载 -v

  可以通过数据挂载，将容器中的文件挂载到容器外，这样即使容器被删了数据也不会消失

  -v 本机路径:容器内路径

  ```bash
  docker run -v /home/test:/home centos #将centos容器中的/home目录中的文件挂载到本机/home/test目录下
  ```


+ 练习：部署mysql

  ```bash
  docker run -d -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD=123456 \
  -v /home/mysql/conf:/etc/mysql/conf.d \
  -v /home/mysql/data:/var/lib/mysql mysql #分别将mysql配置和数据挂载到本地通过-e配置环境设置root密码
  ```

  具名挂载和匿名挂载

  在挂载数据卷的时候可以为数据卷指定名字后续可以在docker volume ls中看到

  ```bash
  -v /容器内路径 #匿名挂载
  -v 卷名:/容器内路径 #具名挂载
  -v /宿主机路径://容器内路径 #具体路径挂载
  ```

  也可以通过docker volume inspect <卷名>来查看卷的具体信息

  共享容器的数据卷

  --volumes-from 容器名

+ docker部署Reids

  先创建本地的数据目录

  ```bash
  mkdir /data/redis
  ```

  部署命令

  ```bash
  docker run \
  --restart=always \
  -d \
  --name redis-container \
  -p 6379:6379 \
  -v /data/redis:/data \
  redis:latest \
  redis-server --appendonly yes \
  --requirepass "123456"
  ```

  ```bash
  docker run \
  --restart=always \ #开机启动
  -d \ #后台运行
  --name redis-container \ #命名容器为redis-container
  -p 6379:6379 \ #端口映射
  -v /data/redis:/data \ #将数据挂载到本地
  redis:latest \ #指定版本
  redis-server --appendonly yes \ #开启AOF持久化
  --requirepass "123456" #设置密码
  ```

  进入容器内通过客户端连接

  ```bash
  docker exec -it redis-container redis-cli
  auth 123456
  ```

  