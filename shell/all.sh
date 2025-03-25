#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "此脚本必须以root用户运行" 1>&2
     exit 1
fi

echo "请选择"  #hu
echo "1. 安装Apache"   
echo "2. 安装MySQL"

read -p "请输入选项：" option

systemctl stop firewalld
systemctl disable firewalld
setenforce 0

case "$option" in
    1)
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

        if [ ! -e /root/httpd-2.4.52.tar.gz ];then
            echo "未检测到安装包，准备下载，请确保网络连接"
            wget http://archive.apache.org/dist/httpd/httpd-2.4.52.tar.gz 
            echo "下载完成"
        fi
        mkdir /usr/src
        tar -zxvf httpd-2.4.52.tar.gz -C /usr/src
        cd /usr/src/httpd-2.4.52
        ./configure --prefix=/usr/local/httpd \
            --enable-so \
            --enable-rewrite \
            --with-mpm=prefork 
        make 
        make install 
        echo "安装成功"
        ln -s /usr/local/httpd/bin/* /usr/local/bin/
        cp /usr/local/httpd/bin/apachectl /etc/init.d/httpd
        sed -i "2i#chkconfig: 35 85 21" /etc/init.d/httpd
        chkconfig  --add httpd
        systemctl start httpd
        echo "启动成功"
        ;;
    2)
    
    read -p "请输入my.cnf配置文件的路径(例如:/path/to/my.cnf):" MY_CNF
    read -p "请输入要更改的MySQL密码:" NEW_PASSWORD

    MYSQL_TAR="mysql-5.7.32-el7-x86_64.tar.gz"
    MYSQL_DIR="/usr/local/mysql"
    DATA_DIR="/data/mysql"


    echo "正在解压MySQL安装包..."
    tar xvfz $MYSQL_TAR


    echo "移动MySQL目录到 $MYSQL_DIR..."
    mv mysql-5.7.32-el7-x86_64/ $MYSQL_DIR


    echo "创建数据目录 $DATA_DIR..."
    mkdir -p $DATA_DIR


    echo "创建mysql用户..."
    useradd -r -s /sbin/nologin -d $MYSQL_DIR mysql


    echo "设置目录权限..."
    chown -R mysql:mysql $MYSQL_DIR
    chown -R mysql $DATA_DIR


    echo "初始化MySQL数据库..."
    cd $MYSQL_DIR
    INIT_OUTPUT=$(bin/mysqld --initialize --user=mysql --basedir=$MYSQL_DIR --datadir=$DATA_DIR 2>&1)
   
    TEMP_PASSWORD=$(echo "$INIT_OUTPUT" | grep -oP "temporary password.*: \K.*")
    if [ -z "$TEMP_PASSWORD" ]; then
     echo "初始化输出: $INIT_OUTPUT"
     echo "无法从输出中提取临时密码，请查看上面的输出并手动记录临时密码"
     echo "请手动输入临时密码:"
     read TEMP_PASSWORD
    else
        echo "临时密码: $TEMP_PASSWORD"
    fi


    echo "删除旧的配置文件(如果存在)..."
    if [ -f /etc/my.cnf ]; then
        rm -f /etc/my.cnf
    fi

    echo "复制配置文件..."
    cp $MY_CNF /etc/

    echo "复制启动脚本到系统目录..."
    cp $MYSQL_DIR/support-files/mysql.server /etc/init.d/mysql


    echo "修改启动脚本..."
    sed -i "s#^basedir=.*#basedir=$MYSQL_DIR#" /etc/init.d/mysql
    sed -i "s#^datadir=.*#datadir=$DATA_DIR#" /etc/init.d/mysql


    echo "创建软链接..."
    ln -sf $MYSQL_DIR/bin/mysql /usr/bin/


    echo "设置启动脚本权限..."
    chmod 755 /etc/init.d/mysql


    echo "添加服务并设置开机启动..."
    chkconfig --add mysql
    chkconfig --level 345 mysql on

    echo "启动MySQL服务..."
    systemctl start mysql


    echo "等待MySQL服务启动..."
    sleep 5


    echo "修改MySQL root密码..."

    if ! command -v expect &> /dev/null; then
        echo "需要安装expect工具才能自动修改密码"
        if [ -f /etc/redhat-release ]; then
            yum install -y expect 
        elif [ -f /etc/lsb-release ]; then
            apt-get update 
            apt-get install -y expect 
        else
            echo "未适配的发行版"
            exit 1
        fi
    fi


    expect -c "
        spawn mysql -u root -p
        expect \"Enter password:\"
        send \"$TEMP_PASSWORD\r\"
        expect \"mysql>\"
        send \"set password=password('$NEW_PASSWORD');\r\"
        expect \"mysql>\"
        send \"quit;\r\"
        expect eof
        "
    

    echo "MySQL安装和配置完成!"
    echo "========================================"
    echo "安装目录: $MYSQL_DIR"
    echo "数据目录: $DATA_DIR"
    echo "临时密码: $TEMP_PASSWORD"
    echo "新密码: $NEW_PASSWORD"
    echo "========================================"
    ;;
    *)
        echo "未知选项"
        exit 1
        ;;
esac
