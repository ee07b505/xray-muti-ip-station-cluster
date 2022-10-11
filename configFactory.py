import sys
import uuid
import random
from common.configFactory import *
from common.outPutFactory import *

log_path = "/var/log/xray/"
log_level = "warning"

if __name__ == '__main__':
    os.system("bash get-ip.sh")
    myconfig = init_config()
    myconfig = init_log_config(myconfig, log_level, log_path)
    name_index = 0
    clear_quick_link_file()
    # 文件读取  构建json数据
    with open('myip.txt', encoding='utf-8') as f:
        for ann in f.readlines():
            # 解析基本数据
            ipaddr = ann.strip('\n')
            inboundTag = "in-" + ipaddr.replace(".", "-")
            outboundTag = "out-" + ipaddr.replace(".", "-")
            mode = "tcp"
            alert_id = 2

            name = sys.argv[1] + "-" + str(name_index)
            uuids = str(uuid.uuid4())
            path = "/c" + str(uuids).replace("-", "")[0:5] + "c/"
            name_index += 1
            port = random.randint(30000, 50000)
            myconfig = build_routing_config(myconfig, inboundTag, outboundTag)
            myconfig = build_default_outbounds_config(myconfig, ipaddr, outboundTag)
            myconfig = build_inbounds_config(myconfig, ipaddr, inboundTag, mode, path, uuids, alert_id, name, port)

            create_quick_link(name, ipaddr, uuids, port=port, alert_id=alert_id, mode=mode, path=path)
    # print(myconfig)

    json_data = json.dumps(myconfig, indent=4, separators=(',', ': '))

    f = open('/usr/local/etc/xray/config.json', 'w')
    f.write(json_data)
    f.close()
    os.system("systemctl restart xray")
    print("网页链接是：")
    os.system("./template/pastebinit-1.5/pastebinit -i ./vmess_link.txt -b dpaste.com")