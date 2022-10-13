import base64
import json
import os


def create_quick_link(ps, address, uuid, port, alert_id, mode, path):
    """

    :param ps: 节点名称
    :param address: 节点地址
    :param uuid: 设备id
    :param port: 端口
    :param alert_id: 加密id
    :param mode: 模式 ws，tcp
    :param path: 路径
    :return: None
    """

    user_config = {
        "v": "2",
        "ps": ps,
        "add": address,
        "port": port,
        "id": uuid,
        "aid": alert_id,
        "scy": "auto",
        "net": mode,
        "type": "none",
        "host": "",
        "path": path,
        "tls": "",
        "sni": "",
        "alpn": ""
    }
    create_code(user_config=user_config)


def create_code(user_config, mode="vmess"):
    aaa = json.dumps(user_config, indent=4, separators=(',', ': '))

    bb = str(aaa).encode()
    cc = base64.b64encode(bb)
    if mode == "vmess":
        vmess_link = f"vmess://{str(cc, 'utf-8')}"
        f = open('vmess_link.txt', 'a')
        f.write(vmess_link)
        f.write("\n")
        f.close()
        print(vmess_link)


def clear_quick_link_file():
    os.system("rm -rf vmess_link.txt")


def list_node(myconfig):
    print("现在有如下节点")
    for v in myconfig.get("inbounds"):
        print(v["ps"])
