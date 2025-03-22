#!/bin/bash


APACHE_HOME="/usr/local/httpd"
APACHECTL="$APACHE_HOME/bin/apachectl"

case "$1" in
    install)
        echo "准备安装依赖"
        if [ -f /etc/redhat-release ]; then
            yum install -y wget gcc make apr-devel apr-util-devel pcre-devel 
        elif [ -f /etc/lsb-release ]; then
            apt-get update 
            apt-get install -y wget gcc make libapr1-dev libaprutil1-dev libpcre3-dev 
        else
            echo "未适配的发行版"
            exit 1
        fi
        echo "依赖安装成功"


        if [ ! -e /root/httpd-2.4.57.tar.gz ];then
            echo "未检测到安装包，准备下载，请确保网络连接"
            wget http://archive.apache.org/dist/httpd/httpd-2.4.57.tar.gz 
            echo "下载完成"
        fi
        mkdir /usr/src
        tar -zxvf httpd-2.4.57.tar.gz -C /usr/src
        cd /usr/src/httpd-2.4.57
        ./configure --prefix=/usr/local/httpd \
            --enable-so \
            --enable-rewrite \
            --with-mpm=prefork 
        make 
        make install 
        echo "安装成功"

        ;;
       
    start)
        $APACHECTL start
        echo "启动Apache服务"
        
        ;;
    stop)
        
        $APACHECTL stop
        echo "停止Apache服务"
        ;;
    restart)
        $APACHECTL restart
        echo "重启Apache服务"
        ;;
    status)
        echo "服务状态："
        if pgrep -f "httpd" >/dev/null; then
            echo "Apache正在运行"
        else
            echo "Apache未运行"
        fi
        ;;
    *)
        echo "用法：$0 {install|start|stop|restart|status}"
        exit 1
esac

