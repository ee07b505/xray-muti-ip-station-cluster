# 初始化
import os.path
from common.outPutFactory import *


def init_config():
    """
    初始化基本配置框架
    :return: myconfig
    """
    myconfig = {"log": {}, "routing": {"rules": []}, "inbounds": [],
                "outbounds": [{"protocol": "blackhole", "tag": "out-block"}, ]}
    return myconfig


def init_log_config(myconfig, log_level, log_path):
    """
    初始化log配置
    :param myconfig: config
    :param log_level: warning,debug,....
    :param log_path: 生成error和access log，必须提前创建
    :return:
    """
    myconfig["log"] = {
        "access": "/var/log/xray/access.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "warning"
    }
    myconfig["log"]["access"] = f"{log_path}access.log"
    myconfig["log"]["error"] = f"{log_path}error.log"
    myconfig["log"]["loglevel"] = log_level
    return myconfig


def init_routing_config(myconfig):
    myconfig["routing"].get("rules").append(
        {
            "type": "field",
            "ip": [
                "geoip:private"
            ],
            "outboundTag": "out-block"
        }
    )
    return myconfig


def build_routing_config(myconfig, inbound_tag, outbound_tag):
    myconfig = init_routing_config(myconfig)

    myconfig["routing"]["rules"].append(
        {
            "type": "field",
            "inboundTag": [
                inbound_tag
            ],
            "outboundTag": outbound_tag
        }
    )
    return myconfig


def build_default_outbounds_config(myconfig, ipaddr, outbound_tag):
    """

    :param myconfig: config
    :param ipaddr: ip地址
    :param outbound_tag: 出口标签
    :return: myconfig
    """
    myconfig["outbounds"].append(
        {
            "sendThrough": ipaddr,
            "protocol": "freedom",
            "tag": outbound_tag
        })
    return myconfig


def build_inbounds_config(myconfig, ipaddr, inbound_tag, mode="tcp", path="/aaa/", uuids=" ", alert_id=2,
                          name="default", port=8443):
    """

    :type port: int default 8443
    :type uuids: uuid gen
    :type path: url path
    :type name: str 节点名称 default
    :param alert_id: int 0-128
    :param myconfig:
    :param ipaddr:
    :param inbound_tag:
    :param mode: tcp,ws
    :return:
    """

    if mode == "tcp":
        myconfig["inbounds"].append(
            {
                "listen": ipaddr,
                "port": port,
                "ps": name,
                "protocol": "vmess",
                "settings": {
                    "clients": [
                        {
                            "id": uuids,
                            "alert_id": alert_id
                        }
                    ]
                },
                "streamSettings": {
                    "network": "tcp"
                },
                "tag": inbound_tag
            }
        )
        return myconfig
    elif mode == "ws":
        myconfig["inbounds"].append(
            {
                "port": port,
                "listen": ipaddr,
                "tag": inbound_tag,
                "ps": name,
                "protocol": "vmess",
                "settings": {
                    "clients": [
                        {
                            "id": uuids,
                            "alterId": alert_id
                        }
                    ]
                },
                "streamSettings": {
                    "network": "ws",
                    "wsSettings": {
                        "path": path
                    }
                }
            }
        )
        return myconfig


def modify_inbounds_config(myconfig, old_name, args):
    """

    :param args: args
    :param myconfig: json config
    :param old_name: node name
    :return: json config
    """
    for index, v in enumerate(myconfig.get("inbounds")):
        if v.get("ps") == old_name:
            uuid = v["settings"]["clients"][0].get("id")
            if args.port is not None:
                myconfig.get("inbounds")[index]["port"] = args.port
            if myconfig.get("inbounds")[index]["streamSettings"].get("network") == "ws" and args.network == "tcp":
                myconfig.get("inbounds")[index]["streamSettings"] = {
                    "network": "tcp"
                }

            if myconfig.get("inbounds")[index]["streamSettings"].get("network") == "tcp" and args.network == "ws":
                path = "/c" + str(uuid).replace("-", "")[0:5] + "c/"
                myconfig.get("inbounds")[index]["streamSettings"] = {
                    "network": args.network,
                    "wsSettings": {
                        "path": path
                    }
                }
            print("这个节点的配置是", json.dumps(v, indent=4, separators=(',', ': ')))
            mode = v["streamSettings"].get('network')
            address = v.get('listen')

            port = v.get("port")
            alert_id = v["settings"]["clients"][0].get("alert_id")

            if mode == 'tcp':
                create_quick_link(ps=old_name, address=address, uuid=uuid, port=port, alert_id=alert_id, mode=mode,
                                  path=None)
            elif mode == "ws":
                """
                    "streamSettings": {
                        "network": "ws",
                        "wsSettings": {
                            "path": path
                    }
                """
                path = v["streamSettings"]["wsSettings"].get('path')
                create_quick_link(ps=old_name, address=address, uuid=uuid, port=port, alert_id=alert_id, mode=mode,
                                  path=path)
            else:
                print("生成链接失败，请检测配置")

    return myconfig


def old_config_exist_check():
    if os.path.exists("/usr/local/etc/xray/config.json"):
        return True
    return False


def restart_xray():
    os.system("systemctl restart xray")


def is_root():
    if not os.geteuid():
        return True
    return False
