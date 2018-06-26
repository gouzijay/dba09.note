

##########################################################################################
https://github.com/yaya9998/notedir		静静笔记
##########################################################################################
数据库管理DBA 进阶	DAY01
	

	一：MySQL 主从同步
		角色分为2种：
			数据库服务 做主master库：被客户端存储数据访问的库
			数据库服务 做从slave库：同步主库的数据到本机
		MySQL主从同步作用：实现数据的自动备份。



	1、主从同步配置：确保数据相同------必须从库必须要有主库上的数据（没有则备份过去）。
			]#mysqldump -uroot -p123456  库或者表  >  /root/xxx.sql		##备份
			】#mysql -uroot -p123456  库   <  /root/xxx.sql   #先传过来，到入数据库中，库要先建
			或者:mysql>source  /root/xxx.sql;
	原理：
	主库Master ,记录数据更改操作
		– 启用 binlog 日志
		– 设置 binlog 日志格式
		– 设置 server_id
	• Slave 运行 2 个线程
		– Slave_IO :复制 master 主机 binlog 日志文件里的 SQL 到本机的 relay-log 文件里。
		– Slave_SQL :执行本机 relay-log 文件里的 SQL 语句,重现 Master 的数据操作。

	【主从工作原理：
	主库查看现在进行的线程：show processlist;
	 主库中有 Binlog Dump（I/O） 线程可以实时通知从库
	I/O线程将主库的binlog日志写入自己（从库机）的中继日志
	SQL线程将中继日志执行。
	】
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
	1、主库服务器配置：192.168.4.51		##确保数据相同------必须从库必须要有主库上的数据（没有则备份过去）
	1）启用 binlog 日志
		】#vim /etc/my.cnf
		[mysqld]
		server_id=51			#
		log-bin=master51
		binlog-format="mixed"
	2）授权备份用户
		mysql>grant replication slave on *.* to repluser@"%" identified by "123456";	##用于主从
		mysql>grant all on *.* to jim@"%"  identified  by "123456";  				##用于客户端
	3)查看正在使用的binlog日志信息（日志文件名、偏移位置）		##下面备用
		mysql>show master status\G

	4）相关文件		##撤销主从需要删除下面文件		##relay中继
		文件名							说明
		master.info				 	连接主服务器信息
		relay-log.info 				中继日志信息
		主机名 -relay-bin.xxxxxx 			中继日志			##默认文件名（可自定义）
		主机名 -relay-bin.index 			中继日志索引文件
	
	2、从库服务器配置：192.168.4.52
	1 ）验证主库授权用户
	2）设置 server_id
		]#vim /etc/my.cnf
		[mysqld]
		server_id=52
	3）发起同步操作---------------指定 Master 相关参数
	mysql>change master to 
		master_host="192.168.4.51", 		#主库IP
		master_user="repluser",  		
		master_password="123456",  
		master_log_file="master51.000001", 	#主库当前使用的日志文件
		master_log_pos=441;			#偏移量

	mysql>start  slave;			##stop  slave;
	mysql>show slave status\G	##查看slave从库状态,没起来，看下面报错Last_IO_Error:和Last_SQL_Error:
		Slave_IO_Running:Yes
		Slave_SQL_Running: Yes
	
	【在从库修改主库的信息方式;
	mysql>stop slave;
	mysql>change master tom 选项=值；
	mysql>start slave;】

	3、客户端验证主从同步配置
	1)授权用户，指定-h主库IP登录mysql
	2)添加数据，主，从验证有无数据，
	
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	主从配置常用参数
		|- ------------------------------------------------------------------------------------------------------------------------------------------------------------------
	`	|适用于 Master 服务器
		|----------------------------------------------------------------------------------------------------------------------------------------------------------------------
		|		选 项					用 途
		|	binlog_do_db=name 		设置 Master 对哪些库记日志		(只允许同步的库)
		|	binlog_ignore_db=name 		设置 Master 对哪些库不记日志	(只不允许同步的库)
		|---------------------------------------------------------------------------------------------------------------------------------------------------------------------
		|适用于 Slave 服务器
		|----------------------------------------------------------------------------------------------------------------------------------------------------------------------
		|		选 项					用 途
		|	log_slave_updates			记录从库更新,允许链式复制( A-B-C ) 	##级联复制
		|	relay_log=dbsvr2-relay-bin 	指定中继日志文件名
		|	replicate_do_db=mysql		仅复制指定库,其他库将被忽略,此选项可设置多条(省略时复制所有库)
		|						
		|	replicate_ignore_db=test   不复制哪些库,其他库将被忽略, ignore-db 与 do-db 只需选用其中一种
		|----------------------------------------------------------------------------------------------------------------------------------------------------------------------

	二、主从同步模式（结构模式、复制模式）
		--------------------------------------------------------------------------------------
		• 基本应用
			– 单向复制:主 --> 从				#主从

		• 扩展应用
			– 链式复制:	主 --> 从 --> 从		#主从从
			– 双向复制:	主 <--> 从			#主主结构（互为主从）
			– 放射式复制:	从 <-- 主 --> 从
		-------------------------------------------------------------------------------------
		1、结构模式
			1）搭建主从从：（参考 单向复制:主 --> 从）
			（1）搭主库服务器
			（2）配置第 1 台从库
				]#vim /etc/my.cnf
				[mysqld]
				server_id=51				
				log-bin=master51
				binlog-format="mixed"
				log_slave_updates			##比主从模式多此项
		   ##重点##【从库的SQL线程执行本机中继日志文件里的SQL命令，不会记录在本机的binlog日志文件里。所以需要上一项）】

		2、复制模式
			复制模式介绍
			• 异步复制( Asynchronous replication )
				– 主库在执行完客户端提交的事务后会立即将结果返给客户端,并不关心从库是否已经接收并处理。
			• 全同步复制( Fully synchronous replication )
				– 当主库执行完一个事务,所有的从库都执行了该事务才返回给客户端。
			• 半同步复制( Semisynchronous replication )
				– 介于异步复制和全同步复制之间,主库在执行完客户端提交的事务后不是立刻返回给客户端,而是等待至
				少一个从库接收到并写到 relay log 中才返回给客户端。
		
		模式配置
			查看是否允许动态加载模块		– 默认允许
			mysql> show variables like "have_dynamic_loading";
				+----------------------+-------+
				| Variable_name        | Value |
				+----------------------+-------+
				| have_dynamic_loading | YES   |
				+----------------------+-------+

			查看已安装的插件
				mysql> select plugin_name,plugin_status  from information_schema.plugins  where  					plugin_name  like '%semi%';
		
		模式配置 (续 1 )		##命令模式（临时配置）；永久配置需写入配置文件/etc/my.cnf 的 [mysqld] 下方
			命令行加载插件				– 用户需有 SUPER 权限(root)
			主库：mysql> INSTALL PLUGIN rpl_semi_sync_master  SONAME 'semisync_master.so';
			从库: mysql> INSTALL PLUGIN rpl_semi_sync_slave	SONAME 'semisync_slave.so';
			

		模式配置(续 2 )
		    启用半同步复制		---------- 在安装完插件后,半同步复制默认是关闭的
			主: mysql> SET GLOBAL rpl_semi_sync_master_enabled = 1;
			从: mysql> SET GLOBAL rpl_semi_sync_slave_enabled = 1;
			查看: mysql> show variables like "rpl_semi_sync_ %_enabled";

		模式配置(续 3 )
			• 配置文件永久启用半同步复制
			– 命令配置临时配置,重启服务会失效
			– 修改后需要重启服务
			– 写在主配置文件 /etc/my.cnf 的 [mysqld] 下方
			主:
				plugin-load=rpl_semi_sync_master=semisync_master.so
				rpl_semi_sync_master_enabled=1
			从:
				plugin-load=rpl_semi_sync_slave=semisync_slave.so
				rpl_semi_sync_slave_enabled=1

		模式配置( 4 )
			• 在有的高可用架构下, master 和 slave 需同时启动
			– 以便在切换后能继续使用半同步复制
			模式配置（续3）主从写入同一台服务器mysql配置文件













































































