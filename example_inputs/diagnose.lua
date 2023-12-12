
module("luci.controller.admin.diagnose", package.seeall)


local nixio  = require "nixio"
local uci    = require "luci.model.uci"
local dtypes = require "luci.tools.datatypes"
local ctypes = require "luci.model.checktypes"
local dbg    = require "luci.tools.debug"
local ctl    = require "luci.model.controller"
local json_m = require "luci.json"
local utl    = require "luci.util"
local sys    = require "luci.sys" 
local err    = require "luci.tools.error"
local userconfig = require "luci.model.userconfig"

local uci_r = uci.cursor()

local CONFIG_NAME       = "dropbear"
local DEFAULT_SSH_PORT  = "33400"
local LOG_TMP           = "/tmp/diagnose.tmp"
local LOG_TAR_TMP	= "/tmp/diagnose.tar.gz"
local LOG_INFO		= "/tmp/diagnose.info"

function ssh_get()
    local data = {}
	
	local ssh_port = ""
             local ssh_port_switch = ""
	uci_r:foreach(CONFIG_NAME, "dropbear",
        function(section)
			ssh_port = section.Port
            ssh_port_switch = section.ssh_port_switch
        end
    )	

	data.ssh_port = ssh_port
    data.ssh_port_switch = ssh_port_switch
	
	return data
end

function ssh_set(http_form)
    local form_data = json_m.decode(http_form.data)
    local params = form_data.params
    local old_data = ssh_get()
	

	local ssh_port     = DEFAULT_SSH_PORT
	local ssh_port_switch = params.ssh_port_switch or "off"
	--local ssh_timeout  = params.ssh_timeout or ""

	local old_ssh_port = old_data.ssh_port
	local old_ssh_switch = old_data.ssh_port_switch

	--check whether any param changed,to indicate whether to reload remote_mngt
	local uci_res
	local cmd = ''

	if (nil ~= ssh_port and old_ssh_port ~= ssh_port) or (old_ssh_switch ~= ssh_port_switch) then
		
		local ssh_entry={}
        uci_r:foreach(CONFIG_NAME, "dropbear",
            function(section)
                ssh_entry[#ssh_entry+1] = uci_r:get_all(CONFIG_NAME, section[".name"])
            end
        )
		
		for _, c in ipairs(ssh_entry) do
            uci_r:set(CONFIG_NAME, c[".name"], "Port", ssh_port)
			uci_r:set(CONFIG_NAME, c[".name"], "ssh_port_switch", ssh_port_switch)
        end

		dbg('dropbear param changed,reload dropbear')
		
        uci_res = uci_r:commit(CONFIG_NAME)

        if not uci_res then
            return false, err.ERR_COM_UCI_COMMIT
        end        

        userconfig.cfg_modify()   
        cmd = "/etc/init.d/dropbear reload;"
        dbg('cmd is ',cmd)
        sys.fork_call(cmd)        
	end

	return ssh_get()
	
end

function log_get( ... )

    luci.sys.fork_call("touch "..LOG_TMP)
    luci.sys.fork_call("echo > ".. LOG_TMP)
    luci.sys.fork_call("echo =========================ps -w=============================== >> ".. LOG_TMP)
    luci.sys.fork_call("ps -w >> ".. LOG_TMP)
    luci.sys.fork_call("echo =========================ifconfig -a========================= >> ".. LOG_TMP)
    luci.sys.fork_call("ifconfig -a >> ".. LOG_TMP)
    luci.sys.fork_call("echo =========================netstat -an========================= >> ".. LOG_TMP)
    luci.sys.fork_call("netstat -an >> ".. LOG_TMP)
    luci.sys.fork_call("echo ==========================top -n 1=========================== >> ".. LOG_TMP)
    luci.sys.fork_call("top -n 1 >> ".. LOG_TMP)
    luci.sys.fork_call("echo ==========================top -n 1=========================== >> ".. LOG_TMP)
    luci.sys.fork_call("top -n 1 >> ".. LOG_TMP)
    luci.sys.fork_call("echo ========================ip link list========================= >> ".. LOG_TMP)
    luci.sys.fork_call("ip link list >> ".. LOG_TMP)
    luci.sys.fork_call("echo =======================ip address show======================= >> ".. LOG_TMP)
    luci.sys.fork_call("ip address show >> ".. LOG_TMP)
    luci.sys.fork_call("echo =======================ip rule show========================== >> ".. LOG_TMP)
    luci.sys.fork_call("ip rule show >> ".. LOG_TMP)
    luci.sys.fork_call("echo =======================ip route show========================= >> ".. LOG_TMP)
    luci.sys.fork_call("ip route show >> ".. LOG_TMP)   
    luci.sys.fork_call("echo ===================iptables-save -c========================== >> ".. LOG_TMP)
    luci.sys.fork_call("iptables-save -c >> ".. LOG_TMP)
    luci.sys.fork_call("echo ===================iptables -t mangle -nvL=================== >> ".. LOG_TMP)      
    luci.sys.fork_call("iptables -t mangle -nvL >> ".. LOG_TMP)
    luci.sys.fork_call("echo ===================iptables -t nat -nvL====================== >> ".. LOG_TMP)                
    luci.sys.fork_call("iptables -t nat -nvL >> ".. LOG_TMP)
    luci.sys.fork_call("echo ===================iptables -nvL============================= >> ".. LOG_TMP)
    luci.sys.fork_call("iptables -nvL >> ".. LOG_TMP)
    luci.sys.fork_call("echo ==============================df============================= >> ".. LOG_TMP)    
    luci.sys.fork_call("df >> ".. LOG_TMP)
    luci.sys.fork_call("echo =====================cat /proc/meminfo======================= >> ".. LOG_TMP)
    luci.sys.fork_call("cat /proc/meminfo >> ".. LOG_TMP)
    luci.sys.fork_call("echo =====================cat /proc/interrupts==================== >> ".. LOG_TMP)
    luci.sys.fork_call("cat /proc/interrupts >> ".. LOG_TMP)
    luci.sys.fork_call("echo =====================cat /proc/softirqs====================== >> ".. LOG_TMP)
    luci.sys.fork_call("cat /proc/softirqs >> ".. LOG_TMP)
    luci.sys.fork_call("echo =====================cat /proc/vmstat======================== >> ".. LOG_TMP)
    luci.sys.fork_call("cat /proc/vmstat >> ".. LOG_TMP)
    luci.sys.fork_call("echo ====================cat /proc/vmallocinfo==================== >> ".. LOG_TMP)
    luci.sys.fork_call("cat /proc/vmallocinfo >> ".. LOG_TMP)
    luci.sys.fork_call("echo ====================conntrack -S============================= >> ".. LOG_TMP)
    luci.sys.fork_call("conntrack -S >> ".. LOG_TMP)
    luci.sys.fork_call("echo ===========================dmesg============================= >> ".. LOG_TMP)
    luci.sys.fork_call("dmesg >> ".. LOG_TMP)       
    luci.sys.fork_call("echo ===========================tddp============================= >> ".. LOG_TMP)
    luci.sys.fork_call("cat  /etc/config/tddp >> ".. LOG_TMP)       

    luci.sys.exec("tar -zvcf "..LOG_TAR_TMP.." "..LOG_TMP.." 2>&1 | tee "..LOG_INFO)   

 
    local reader = sys.ltn12_popen("cat " ..LOG_TAR_TMP)
    luci.http.header('Content-Disposition', 'attachment; filename="log-%s-%s.bin"' % {
        luci.sys.hostname(), os.date("%Y-%m-%d")})
    luci.http.prepare_content("application/x-bin")
    luci.ltn12.pump.all(reader, luci.http.write)

    debug("finish back up ...")
    return true
end


--- Dispatch table
local dispatch_tbl = {
	["setting"] = {
        ["get"]   = {cb = ssh_get},
        ["set"]  = {cb = ssh_set},
    },
    ["log"] = {
        ["download"]   = {cb = log_get}
    },
}

function dispatch(http_form)
    return ctl.dispatch(dispatch_tbl, http_form)
end

function _index()
    return ctl._index(dispatch)
end

--- Module entrance
function index()
    entry({"admin", "diagnose"}, call("_index")).leaf = true
end
