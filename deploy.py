#!/bin/env python
#coding=utf-8

import sys 
import json
import time
import logging

from func.overlord.client import Client

logging.basicConfig(level = logging.INFO,
    format = '%(asctime)s %(filename)s[line:%(lineno)d] %(levelname)s %(message)s',
    datefmt = '%Y-%m-%d %H:%M:%S',
    filename = 'logs/info/info.log',
    )   

cmd_list_file = "$HOME/.poll_cmd_list.txt"
poll_cmd_log = "poll_cmd_dog.log"
poll_cmd = "poll_cmd_dog.sh"

class BaseDeploy(object):
    def __init__(self, host):
        self.host = host

        logging.info("Contruct Func client on %s" % host)
        self.client = Client(host)

    def send(self, local, remote, file):
        logging.info("Send %s/%s to %s:%s/%s" % (local, file, self.host, remote, file))
        return self.client.local.copyfile.send("%s/%s" % (local, file), "%s/%s" % (remote, file))

    def run(self, cmd):
        logging.info("Run command[%s] on %s" % (cmd, self.host))
        res = self.client.command.run(cmd)
        return res 

class FooYunDeploy(BaseDeploy):
    def __init__(self, host):
        super(FooYunDeploy, self).__init__(host)

        self.ret_ok = 0 
        self.ret_err = -1
        self.res = {'host': self.host, 'ret': self.ret_err, 'ok': '', 'err': ''} 

    def encode(self, res):
        return json.dumps(res, encoding='utf-8', ensure_ascii=True)

    def _stop(self, type, grep):
        #delete from queue file first
        self.run('echo "[ PROMPT `date +\'%%Y-%%m-%%d %%H:%%M:%%S\'` ] manual stopping: %s" >>%s' % (grep, poll_cmd_log))
        self.run('lnum=`fgrep -n "%s" %s |awk -F: \'{print $1}\' |head -1`; [ -n "$lnum" ] && sed -i "${lnum}d" %s' % (grep, cmd_list_file, cmd_list_file))

        #exclude current process itself
        #proxy
        stop_cmd = "ps x|fgrep '%s' |fgrep -v 'fgrep' |fgrep -v '%s' |awk '{print $1}' |xargs kill -9" % (grep, sys.argv[0])
        if type == '2':
            ##dataserver
            ##kill cmd_dog.sh first
            #stop_cmd = "ps x|fgrep '%s' |fgrep -v 'fgrep' |fgrep -v '%s' |fgrep 'cmd_dog.sh' |awk '{print $1}' |xargs kill -9" % (grep, sys.argv[0])
            #self.run(stop_cmd)
            #stop_cmd = "echo -e '*1\\r\\n$8\\r\\nshutdown\\r\\n' |nc -w 10 `echo '%s' |sed 's/.* -i \\(\\S\\+\\) -p \\(\\S\\+\\) .*/\\1 \\2/'`" % grep

            stop_cmd = "ps x|fgrep '%s' |fgrep -v 'fgrep' |fgrep -v '%s' |awk '{print $1}' |xargs kill " % (grep, sys.argv[0])
        res = self.run(stop_cmd)
        if res[self.host][0] != 0:
            logging.error("Stop fail: %s" % res)
            self.res['err'] = "Stop fail: %s" % res[self.host][2]
        else:
            self.res['ret'] = self.ret_ok
            self.res['ok'] = "Success"

        return self.res


    def stop(self, type, grep):
        res = self._stop(type, grep)
        return self.encode(res)

    def exc(self, cmd):
        res = self.run(cmd)
        if res[self.host][0] != 0:
            logging.error("Exec fail: %s" % res)
            self.res['err'] = "Exec fail: %s" % res[self.host][2]
        else:
            self.res['ret'] = self.ret_ok
            self.res['ok'] = res[self.host][1]

        return self.encode(self.res)

    def _restart(self, type, local, remote, file_i386, file_x86_64, start_cmd, grep):
        if file_i386.find('i386.tar.gz') == -1:
            logging.error("file_i386 should name with 'i386.tar.gz'")
            self.res['err'] = "file_i386 should name with 'i386.tar.gz'"
            return self.res

        if file_x86_64.find('x86_64.tar.gz') == -1:
            logging.error("file_x86_64 should name with 'x86_64.tar.gz'")
            self.res['err'] = "file_x86_64 should name with 'x86_64.tar.gz'"
            return self.res

        res = self.run("uname -i")
        if res[self.host][0] != 0 or not res[self.host][1]:
            logging.error("Uname fail: %s" % res)
            self.res['err'] = "Uname fail: %s" % res[self.host][2]
            return self.res

        file = file_i386 if res[self.host][1] == 'i386\n' else file_x86_64

        res = self.run("ls %s/%s" % (remote, file))
        if res[self.host][0] == 0 and res[self.host][1]:
            logging.warn("%s/%s existed, no need distribute" % (remote, file))
        else:
            res = self.send(local, remote, file)
            if res[self.host][0] != 0:
                logging.error("Send fail: %s" % res)
                self.res['err'] = "Send fail: %s" % res[self.host][2]
                return self.res

        #delete from queue file first
        self.run('lnum=`fgrep -n "%s" %s |awk -F: \'{print $1}\' |head -1`; [ -n "$lnum" ] && sed -i "${lnum}d" %s' % (grep, cmd_list_file, cmd_list_file))

        #exclude current process itself
        #proxy
        stop_cmd = "ps x|fgrep '%s' |fgrep -v 'fgrep' |fgrep -v '%s' |awk '{print $1}' |xargs kill -9" % (grep, sys.argv[0])
        if type == '2':
            ##dataserver
            ##kill cmd_dog.sh first
            #stop_cmd = "ps x|fgrep '%s' |fgrep -v 'fgrep' |fgrep -v '%s' |fgrep 'cmd_dog.sh' |awk '{print $1}' |xargs kill -9" % (grep, sys.argv[0])
            #self.run(stop_cmd)
            #stop_cmd = "echo -e '*1\\r\\n$8\\r\\nshutdown\\r\\n' |nc -w 10 `echo '%s' |sed 's/.* -i \\(\\S\\+\\) -p \\(\\S\\+\\) .*/\\1 \\2/'`" % grep

            stop_cmd = "ps x|fgrep '%s' |fgrep -v 'fgrep' |fgrep -v '%s' |awk '{print $1}' |xargs kill " % (grep, sys.argv[0])
        res = self.run(stop_cmd)
        if res[self.host][0] != 0:
            logging.warn("Stop fail, may timeout: %s" % res)

        dest_dir = None
        if type == '1': dest_dir = 'proxy'
        if type == '2': dest_dir = 'dataserver'
        if not dest_dir:
            logging.error("Type[%s] not correct" % type)
            self.res['err'] = "Type[%s] not correct" % type
            return self.res

        res = self.run("mkdir -p %s/%s" % (remote, dest_dir))
        if res[self.host][0] != 0:
            logging.error("Create bin dir fail: %s" % res)
            self.res['err'] = "Create bin dir fail: %s" % res[self.host][2]
            return self.res
            
                    res = self.run("cd %s && tar xf %s" % (remote, file))
        if res[self.host][0] != 0:
            logging.error("Untar fail: %s" % res)
            self.res['err'] = "Untar fail: %s" % res[self.host][2]
            return self.res

        src_dir = file.replace('.tar.gz', '')
        #backup old file
        self.run("cd %s/%s; mv data-server data-server.old; mv fy_proxy fy_proxy.old" % (remote, dest_dir))
        res = self.run("cd %s && cp -f %s/* %s/" % (remote, src_dir, dest_dir))
        if res[self.host][0] != 0:
            logging.error("Copy execute file fail: %s" % res)
            self.res['err'] = "Copy execute file fail: %s" % res[self.host][2]
            return self.res

        #add new cmd to queue file, and start poll_cmd_dog if not exist
        self.run('echo "[ PROMPT `date +\'%%Y-%%m-%%d %%H:%%M:%%S\'` ] manual starting: %s" >>%s' % (start_cmd, poll_cmd_log))
        self.run('echo "[ PROMPT `date +\'%%Y-%%m-%%d %%H:%%M:%%S\'` ] manual starting: %s" >>%s/%s/start.log' % (start_cmd, remote, dest_dir))
        self.run('echo "%s/%s/%s" >>%s && (nohup sh %s/%s/%s %s >>%s 2>&1 &)' \
                % (remote, dest_dir, start_cmd, cmd_list_file, remote, dest_dir, poll_cmd, cmd_list_file, poll_cmd_log))

        if res[self.host][0] != 0:
            logging.error("Start fail: %s" % res)
            self.res['err'] = "Start fail: %s" % res[self.host][2]
            return self.res

        t = 0.2
        logging.info("Sleep %0.1f seconds then check process" % t)
        time.sleep(t)
        res = self.run("ps x |fgrep -v 'fgrep' |fgrep 'poll_cmd_dog.sh'")
        if res[self.host][0] != 0 or not res[self.host][1]:
            logging.error("Start fail, process exited: %s" % res)
            self.res['err'] = "Start fail, process exited"
            return self.res

        res = self.run("cd %s && rm -rf %s && rm %s" % (remote, src_dir, file))
        if res[self.host][0] != 0:
            logging.error("Clean tarball fail: %s" % res)
            self.res['err'] = "Clean tarball fail: %s" % res[self.host][2]
            return self.res

        self.res['ret'] = self.ret_ok
        self.res['ok'] = "Success"

        return self.res


    def restart(self, type, local, remote, file_i386, file_x86_64, start_cmd, grep):
        res = self._restart(type, local, remote, file_i386,file_x86_64, start_cmd, grep)
        return self.encode(res)

    def get(self, remotefile, localfolder):
        res = self.client.local.getfile.get(remotefile, localfolder)
        if res[0]:
            logging.error("Get fail: %s" % res[1])
            self.res['err'] = res[1]
            return self.res

        self.res['ret'] = self.ret_ok
        self.res['ok'] = "Success"

        return self.res

    def list(self, remotepath):
        res = self.run("ls -lF %s |awk '{if(NR > 1)print $NF,$5}'" % remotepath)
        if res[self.host][2]:
            logging.error("List fail: %s" % res)
            self.res['err'] = res[self.host][2]
            return self.res

        self.res['ret'] = self.ret_ok
        self.res['ok'] = res[self.host][1]

        return self.res


    def start_http(self, local, remote, start_script, port_range):
        res = self.send(local, remote, start_script)
        if res[self.host][0] != 0:
            logging.error("Send fail: %s" % res)
            self.res['err'] = "Send fail: %s" % res[self.host][2]
            return self.encode(self.res)

        res = self.run("cd %s && sh %s %s %s" % (remote, start_script, remote, port_range))
        if res[self.host][0] != 0:
            logging.error("Start SimpleHTTPServer fail: %s" % res)
            self.res['err'] = "Start SimpleHTTPServer fail: %s" % res[self.host][2]
            return self.encode(self.res)

        self.res['ret'] = self.ret_ok
        self.res['ok'] = res[self.host][1]
        return self.encode(self.res)

def main(argv):
    deploy = FooYunDeploy(argv[1])
    method = {'restart': deploy.restart, 'stop': deploy.stop,
                'get':deploy.get, 'list':deploy.list,
                'exc':deploy.exc, 'start_http':deploy.start_http}

    return method[argv[0]](*tuple(argv[2:]))

if __name__ == '__main__':
#    import pdb; pdb.set_trace()
    try:
        res = main(sys.argv[1:])
    except Exception, e:
        logging.error("Call error: argv%s: %s" % (sys.argv, e))
        res = {"host": sys.argv[2] if len(sys.argv) >= 3 else 'UNKNOWN', "ok": "", "err": "%s" % e, "ret": -1}

    logging.info("Call Result: %s" % res)
    print res
