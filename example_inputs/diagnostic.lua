--[[
Copyright(c) 2008-2015 Shenzhen TP-LINK Technologies Co.Ltd.

File    :  diagnostic.lua
Details :  
Author  :  YuanFengjia
Version :  1.0.0
Date    :  2015-09-04
]]--

module("luci.controller.admin.diagnostic", package.seeall)


local dbg  = require "luci.tools.debug"
local ubus = require "ubus"
local io   = require "io"
local util = require "luci.util"
local uci  = require "luci.model.uci"
local ctl  = require "luci.model.controller"
local dtype = require "luci.tools.datatypes"
local json = require "luci.json"

local uci_r = uci.cursor()
--form = form.Form(uci_r, {"ipaddr"})

local PING_PATH  = "/tmp/diagnostic/luci_ping"
local TRACE_PATH = "/tmp/diagnostic/luci_trace"
-- local LOCK_PATH  = "/tmp/diagnostic/luci_lockfile"
local FIN_STATUS = "/tmp/diagnostic/luci_FIN"
local PATH_DIR   = "/tmp/diagnostic"
local BEGIN_TIME = "/tmp/diagnostic/luci_TIME"

local g_stop = true

---compact the json date
--@param
local function compact_data(types, ip, iface, count, pkt, timeout, ttl, finish, result)
    return {
        type    = types,
        ipaddr  = ip,
		iface   = iface,
        count   = count,
        pktsize = pkt,
        timeout = timeout,
        ttl     = ttl,
        finish  = finish,
        my_result  = result
    }
end

local function get_cfg_data()
    local uci_r = uci.cursor()
    return {
        my_count   = uci_r:get("diagnostic", "params", "count") or 4,
        my_pkt     = uci_r:get("diagnostic", "params", "pktsize") or 64,
        my_timeout = uci_r:get("diagnostic", "params", "timeout") or 800,
        my_ttl     = uci_r:get("diagnostic", "params", "ttl") or 20
    }
end

local function set_cfg_data(count, pkt, timeout, ttl)
    local uci_r = uci.cursor()
    uci_r:set("diagnostic", "params", "count", count)
    uci_r:set("diagnostic", "params", "pktsize", pkt)
    uci_r:set("diagnostic", "params", "timeout", timeout)
    uci_r:set("diagnostic", "params", "ttl", ttl)
    uci_r:commit("diagnostic")
end

local function reset_cfg_data()
    set_cfg_data(4, 64, 800, 20)
end

local function read_from_File(filename)
    local ret = " "

    local t_file = io.open(filename)
    if t_file then
        ret = t_file:read("*all")
        t_file:close()
    end

    return ret
end

local function zone_get_effect_devices(t)
    local devices 

	local cmd = ". /lib/zone/zone_api.sh; zone_get_effect_devices " .. t
	dbg("cmd:",cmd)
    local ff = io.popen(cmd, "r");
    if not ff then
        return devices
    end

    local l = ff:read("*l")
    return l
end

local function get_ip_list()
--[[
	local list={}
	uci_r:foreach("network","interface",
		function(section)
			dbg.dumptable(section)
            list[#list + 1] = uci_r:get_all("ipgroup", section[".name"])        
		end
	)
]]--
	local cmd= "ifconfig -a|grep -i \"inet addr\" |awk '{print $2}' |awk -F \":\" '{print $2}'"
	dbg("cmd:",cmd)
    local list=util.execl(cmd)
    return list
end

local function check_self_ip(ip)
	local ip_list=get_ip_list()

	for _,dutip in ipairs(ip_list) do
		if dutip == ip then
			dbg("it's selfip,ip match:",dutip)
			return true
		end
	end

	return false
end

--- ping action functon
--

local function ping_action(http_form)
    local uci_r = uci.cursor()
	local form_data = json.decode(http_form.data)
    local params = form_data.params

    local types      = params["type"] or ""
    local my_ip      = params["ipaddr"] or ""
    local my_count   = params["count"] or ""
    local my_pkt     = params["pktsize"] or ""
    local my_timeout = params["timeout"] or ""
    local my_ttl     = uci_r:get("diagnostic", "params", "ttl") or 20
    local my_result  = " "
	local my_iface   = params["iface"] or ""
	local my_dev   = my_iface
	local my_iface2  = my_iface

	local is_self_ip=check_self_ip(my_ip)
	
	dbg("my_iface:",my_iface)
	my_iface = zone_get_effect_devices(my_iface)
	dbg("my_iface:",my_iface)
	dbg("my_dev:",my_dev)


    local t_timeout = tonumber(my_timeout)
    local t_pkt     = tonumber(my_pkt)

    --check ip is legal or not
    if my_ip and my_ip:match("^[a-zA-Z0-9%-%.:_]+$") then
		--dbg("--enter my_ip--")
		--dbg("my_ip:",my_ip)
--[[
		if my_dev and not my_ip:match("^[0-9.]+$") then
			local get_ip_cmd="dnsq %s %s -t 1 2>&1" % {my_dev, my_ip}
			--dbg("---get_ip_cmd---",get_ip_cmd)
			my_ip=luci.sys.exec(get_ip_cmd)
			dbg("---get my_ip---",my_ip)
		end
]]--

        -- check count is legal or not
        if my_count == "" then
            my_count = uci_r:get("diagnostic", "params", "count") or 4
        end

        --check pkt is legal or not
        if not t_pkt then
            t_pkt = uci_r:get("diagnostic", "params", "pktsize") or 64
            t_pkt = tonumber(t_pkt)
        elseif t_pkt < 0 then
            t_pkt = 0
        end


        -- check the timeout format

        if not t_timeout then
            my_timeout = uci_r:get("diagnostic", "params", "timeout") or 800
            t_timeout = 1
        elseif t_timeout > 1000 then
            t_timeout = t_timeout / 1000
            t_timeout = math.floor(t_timeout)
        else
            t_timeout = 1
        end

        -- Save params for after reading
        set_cfg_data(my_count, t_pkt, t_timeout, my_ttl)

		dbg("mkdir patch")
        luci.sys.fork_call("mkdir " .. PATH_DIR)
        if nixio.fs.access(PING_PATH) then
            nixio.fs.remove(PING_PATH)
        end

		dbg("echo time")
        luci.sys.fork_call("echo %d > %q" % {os.time(), BEGIN_TIME})

        -- luci.sys.fork_call("touch " .. LOCK_PATH)
        -- luci.sys.fork_call("lock -s " .. LOCK_PATH)
        luci.sys.fork_call("echo 'START' > " .. FIN_STATUS)

        -- do the ping action

        local MAX = 0
        local MIN = 999999
        local AVG = 0
        local avg_tbl  = {}
        local t_count  = 0
        local bad_addr = 0
        local pkt_loss = 0
        local pkt_rcv  = 0
        local t_time   = 0
        local real_ip  = my_ip

		dbg("begin to ping")
        while true do
			dbg("xxx")
            -- check finish status
            local fin_file = io.open(FIN_STATUS)
            local fin_ln = fin_file:read("*l")

            fin_file:close()

            if fin_ln == "FINISH" then 
			    dbg("000")
                break 
            end
            
            -- ping one time
            t_count  = t_count + 1
			dbg("ping!!!")
			local my_cmd
			local lines
			if is_self_ip==true then
				my_cmd = "ping -c 2 -W %d -s %d %q 2>&1" % {t_timeout, t_pkt, my_ip}
            	lines = luci.sys.exec("ping -c 1 -W %d -s %d %q 2>&1" % {t_timeout, t_pkt, my_ip})
			else
				my_cmd = "ping -I %s -c 2 -W %d -s %d %q 2>&1" % {my_iface, t_timeout, t_pkt, my_ip}
            	lines = luci.sys.exec("ping -I %s -c 1 -W %d -s %d %q 2>&1" % {my_iface, t_timeout, t_pkt, my_ip})
			end
			dbg("my_cmd:",my_cmd)
			dbg("lines:",lines)
            if lines then

                local timeout_id = 1
                local t_file = io.open(PING_PATH, "a")
                while not t_file do
                    t_file = io.open(PING_PATH, "a")
                    dbg("no file open")
                end
                local ln_tbl = util.split(lines)
				dbg("ln_tbl:",ln_tbl)
				dbg.dumptable(ln_tbl)
                local ln
                for i, ln in pairs(ln_tbl) do

                    -- write in the first line.
                    if t_count == 1 and i == 1 then

                        if ln:match("^PING") then
                            t_file:write(ln .. "\n")
                            real_ip = ln:match(".*%((.*)%).*") or my_ip
                            
                        elseif ln:match("^ping") then
						    dbg("111")
                            t_file:write("There is no response from DNS.\n    please check the domain name or DNS.\n")
                            bad_addr = 1
                            break

                        elseif ln == "" then
						    dbg("222")
                            t_file:write("There is no response from DNS.\n    please check the domain name or DNS.\n")
                            bad_addr = 1
                            break
                        end

                    end

                    --wirte in the result line, record the time
                    if ln:match("bytes from") then

                        if ln:find("time=") then
                            --get the round-time
                            local t_ttl = ln:match(".*ttl=(%d+) time.*")
                            t_time = ln:match(".*time=([%d%.]+) ms.*")
                            avg_tbl[#avg_tbl + 1] = t_time
                            ln = string.format("Reply from %s:  bytes=%d  ttl=%d  seq=%d  time=%.3f ms",
                                real_ip, t_pkt, t_ttl, t_count, t_time)
                        else
                            local t_ttl = ln:match(".*ttl=(%d+).*")
                            t_time = "0.1"
                            avg_tbl[#avg_tbl + 1] = t_time
                            ln = string.format("Reply from %s:  bytes=%d  ttl=%d  seq=%d  time<%.3f ms",
                                real_ip, t_pkt, t_ttl, t_count, t_time)
                        end
                        
                        t_file:write(ln .. "\n")
                        pkt_rcv = pkt_rcv + 1
                        timeout_id = 0
						dbg("666")
                        break
                    elseif ln:find("^ping") then
                        t_file:write("Network is unreachable.\n    please check the ip address.\n")
                        bad_addr = 1
						dbg("777")
                        break
                    end

                end

				dbg("aaa")
                -- if no result line and no bad addr , write in the request time out and pktloss++
                if timeout_id == 1 and bad_addr ~= 1 then
                    t_file:write("Request timed out!\n")
                    pkt_loss = pkt_loss + 1
                end

                t_file:close()
            end

			dbg("bbb")
            --if bad_addr ,then stop

            if bad_addr == 1 then 
			    dbg("888")
                break 
            end

			dbg("ccc")
            -- t_count  = t_count + 1
            t_time   = tonumber(t_time)
            my_count = tonumber(my_count)

            if t_time > MAX then 
                MAX = t_time 
            end
            if t_time < MIN then 
                MIN = t_time 
            end
			dbg("my_count",my_count)
			dbg("t_count",t_count)
            if my_count <= t_count then 
			    dbg("999")
                break 
            end

        end

		dbg("finish1")
        luci.sys.fork_call("echo 'FINISH' > " .. FIN_STATUS)

        --add the statistic of the ping result if not bad_addr
        if bad_addr == 0 then
            local t_file
            if pkt_rcv > 0 then
                local SUM = 0
                local count
                for i, k in pairs(avg_tbl) do
                    SUM   = SUM + k
                    count = i
                end
                AVG = SUM / count
                t_file = io.open(PING_PATH, "a")
                while not t_file do
                    t_file = io.open(PING_PATH, "a")
                    dbg("no file open")
                end
                t_file:write("\n--- Ping Statistic %q ---\n" % my_ip)
                t_file:write("Packets: Sent=%d, Received=%d, Lost=%d (%.2f%% loss)\n" 
                    % {t_count, pkt_rcv, pkt_loss, pkt_loss * 100 / t_count})
                t_file:write("Round-trip min/avg/max = %.3f/%.3f/%.3f ms\n" % {MIN, AVG, MAX})
                t_file:close()
            else
                t_file = io.open(PING_PATH,"a")
                while not t_file do
                    t_file = io.open(PING_PATH,"a")
                    dbg("no file open")
                end
                t_file:write("\n--- Ping Statistic %q ---\n" % my_ip)
                t_file:write("Packets: Sent=%d, Received=%d, Lost=%d (%.2f%% loss)\n"
                    % {t_count, pkt_rcv, pkt_loss, pkt_loss * 100 / t_count})
                t_file:close()
            end

        end

        -- luci.sys.fork_call("lock -u " .. LOCK_PATH)
    end

    my_result = read_from_File(PING_PATH)

    return compact_data(types, my_ip, my_iface2, my_count, t_pkt, my_timeout, my_ttl, "1", my_result)

end


function check_network()
    local uci_r = uci.cursor()
    local _ubus = ubus.connect()
    local ifname = uci_r:get("network", "GE1", "ifname") or "eth0"

    if _ubus then
        local data = _ubus:call("network.device", "status", {})
        if data and data[ifname] then
            if data[ifname]["link"] then
                return true
            end
        end
    end
    return false
end


local function trace_action(http_form)

    local uci_r      = uci.cursor()
	local form_data  = json.decode(http_form.data)
    local params     = form_data.params
	
    local types      = params["type"] or ""
    local my_ip      = params["ipaddr"] or ""
    local my_count   = uci_r:get("diagnostic", "params", "count") or 4
    local my_pkt     = uci_r:get("diagnostic", "params", "pktsize") or 64
    local my_timeout = uci_r:get("diagnostic", "params", "timeout") or 800
    local my_ttl     = params["ttl"] or ""
    local my_result  = " "
    local bad_addr   = 1
	local my_iface   = params["iface"] or ""
	local my_iface2  = my_iface
	
	my_iface = zone_get_effect_devices(my_iface)

    local nixio = require "nixio"

    local pid = nixio.fork()
    -- dbg("Start: " .. pid)

    if pid == 0 then  -- child

        -- check ip is legal or not
        if my_ip and my_ip:match("^[a-zA-Z0-9%-%.:_]+$") then

            -- check ttl is legal or not
            if my_ttl == "" or tonumber(my_ttl) < 1 or tonumber(my_ttl) > 30 then
                my_ttl = uci_r:get("diagnostic", "params", "ttl") or 20
            end

            -- Save params for after reading
            set_cfg_data(my_count, my_pkt, my_timeout, my_ttl)

            --table of the result
            luci.sys.fork_call("mkdir " .. PATH_DIR)
            if nixio.fs.access(TRACE_PATH) then
                nixio.fs.remove(TRACE_PATH)
            end

            --luci.sys.fork_call("echo 'Begin to Trace ...' > "..TRACE_PATH)
            luci.sys.fork_call("echo %d > %q" % {os.time(), BEGIN_TIME})
            -- luci.sys.fork_call("touch " .. LOCK_PATH)
            -- luci.sys.fork_call("lock -s " .. LOCK_PATH)

            -- do the trace action
            local t_util = io.popen("traceroute -i %s -I -w 1 -m %d %q 2>&1" % {my_iface, my_ttl, my_ip })

            -- got the result
            if t_util then
                while true do
                    local ln = t_util:read("*l")
                    if bad_addr == 1 then
                        -- if not check_network() then
                        --     ln = ln and ln .. " !N" or "traceroute to " .. my_ip .. " ... !N"
                        -- elseif ln and ln:find("traceroute to") then
                        if ln and ln:find("traceroute to") then
                            if dtype.ipaddr(my_ip) then
                                ln = ln:gsub(" %(.*%)", "")
                            end
                        else
                            ln = "BAD ADDRESS"
                        end
                        bad_addr = 0
                    end

                    if ln then
                        if ln:find("Network is unreachable") then
                            ln = " 1 *  *  *  !N"
                        end

                        local t_file = io.open(TRACE_PATH, "a")
                        while not t_file do
                            t_file = io.open(TRACE_PATH, "a")
                            dbg("no file open")
                        end
                        t_file:write(ln .. "\n")
                        t_file:close()
                    else
                        break
                    end
                end
                t_util:close()
            end

            -- luci.sys.fork_call("lock -u " .. LOCK_PATH)
        end

        my_result = read_from_File(TRACE_PATH) or " "

        -- Adding the finish message.
        local last = "Trace Complete.\n"
        if my_result:find("!H") then
            last = "Host is Unreachable.\n"
        elseif my_result:find("!N") then
            last = "Network is Unreachable.\n"
        elseif my_result:find("!P") then
            last = "Protocol is Unreachable.\n"
        elseif my_result:find("!S") then
            last = "Source Route Failed.\n"
        end

        local t_file = io.open(TRACE_PATH, "a")
        while not t_file do
            t_file = io.open(TRACE_PATH, "a")
            dbg("no file open")
        end
        t_file:write(last)
        t_file:close()
        my_result = my_result .. last
    else  -- parent
        nixio.waitpid(pid)
    end

    -- dbg("Exit: " .. pid)
    return compact_data(types, my_ip, my_iface2, my_count, my_pkt, my_timeout, my_ttl, "1", my_result)
end

--- Start action function
--


local function start_action(http_form)
    local form_data = json.decode(http_form.data)
    local params = form_data.params
    local types = params.type or ""
	
    local ret
    if types == "0" then
	    dbg("ping begin!")
        ret = ping_action(http_form)
    elseif types == "1" then
	    dbg("troute begin!")
        ret = trace_action(http_form)
    end

    return ret or false

end

local function found_pid(my_cmd)

    local ps_info = io.popen("ps | grep %q" % my_cmd)
    local pid = false
    local tbl

    if ps_info then
        while true do
            local line = ps_info:read("*l")
            if not line then 
                break 
            end
            line = util.trim(line)
            tbl  = util.split(line, " +", 99, true)
            local cmd = tbl[5]
            --dbg(cmd)
            if cmd and cmd:match("^" .. my_cmd) then
                pid = tbl[1]
                --dbg(pid)
                break
            end
        end
        ps_info:close()
    end
    return pid
end


local function ping_continue_action(http_form)

    local uci_r      = uci.cursor()
	local form_data  = json.decode(http_form.data)
    local params     = form_data.params
	
    local types      = params["type"]    or 0
    local my_ip      = params["ipaddr"]  or ""
    local my_count   = params["count"]   or uci_r:get("diagnostic", "params", "count")
    local my_pkt     = params["pktsize"] or uci_r:get("diagnostic", "params", "pktsize")
    local my_timeout = params["timeout"] or uci_r:get("diagnostic", "params", "timeout")
    local my_ttl     = params["ttl"]     or uci_r:get("diagnostic", "params", "ttl")
    local my_result  = " "
	local my_iface   = params["iface"]  or ""

    local finish = 1
    --local pid = found_pid(my_cmd)

    local fin_file = io.open(FIN_STATUS)
    local fin_ln = fin_file:read("*l")
    fin_file:close()

    if fin_ln == "START" then
        finish = 0
    else
        -- luci.sys.fork_call("lock -w " .. LOCK_PATH)
    end

    local start_time = read_from_File(BEGIN_TIME)
    local running_time = os.time() - tonumber(start_time)
	--dbg("start_time:",start_time)
	--dbg("os.time:",os.time())

    my_result = read_from_File(PING_PATH) or " "
	--dbg("my_result:",my_result)

    if running_time > 5 and my_result == " " then
        finish = 1
        luci.sys.fork_call("echo 'FINISH' > " .. FIN_STATUS)
        local pid = found_pid("ping")
        if pid then
            luci.sys.call("kill -9 %q" % pid)
        end
		dbg("333")
        my_result = "There is no response from DNS.\n    please check the domain name or DNS.\n"
    end

    return compact_data(types, my_ip, my_iface, my_count, my_pkt, my_timeout, my_ttl, finish, my_result)

end

--- trace continue action
--

local function trace_continue_action(http_form)

    local uci_r      = uci.cursor()
	local form_data  = json.decode(http_form.data)
    local params     = form_data.params
	
    local types      = params["type"]    or 1
    local my_ip      = params["ipaddr"]  or ""
    local my_count   = params["count"]   or uci_r:get("diagnostic", "params", "count")
    local my_pkt     = params["pktsize"] or uci_r:get("diagnostic", "params", "pktsize")
    local my_timeout = params["timeout"] or uci_r:get("diagnostic", "params", "timeout")
    local my_ttl     = params["ttl"]     or uci_r:get("diagnostic", "params", "ttl")
    local my_result  = " "
	local my_iface   = params["iface"]  or ""

    local finish = 1
    local pid    = found_pid("traceroute")

    if pid then
        finish = 0
    else
        -- luci.sys.fork_call("lock -w " .. LOCK_PATH)
    end

    my_result = read_from_File(TRACE_PATH) or " "
    if my_result:find("BAD ADDRESS") then

        finish = 1
        if pid then
            luci.sys.call("kill -9 %q" % pid)
        end
		dbg("444")
        my_result = "There are no response from DNS.\n    please check the domain name or DNS.\n"
    end

    return compact_data(types, my_ip, my_iface, my_count, my_pkt, my_timeout, my_ttl, finish, my_result)

end

--- Continue action function
--

local function continue_action(http_form)
    local form_data  = json.decode(http_form.data)
    local params     = form_data.params
	
    local types = params["type"] or ""
    local ret

    if types == "0" then
        ret = ping_continue_action(http_form)
    elseif types == "1" then
        ret = trace_continue_action(http_form)
    end

    return ret or false

end



--- Stop action function
--

local function stop_cmd(http_form, my_cmd, my_path)

    local uci_r      = uci.cursor()
	local form_data  = json.decode(http_form.data)
    local params     = form_data.params
	
    local my_ip      = params["ipaddr"]  or ""
    local my_count   = params["count"]   or uci_r:get("diagnostic", "params", "count")
    local my_pkt     = params["pktsize"] or uci_r:get("diagnostic", "params", "pktsize")
    local my_timeout = params["timeout"] or uci_r:get("diagnostic", "params", "timeout")
    local my_ttl     = params["ttl"]     or uci_r:get("diagnostic", "params", "ttl")
    local types      = params["type"]    or ""
    local my_result  = " "
	local my_iface   = params["iface"]  or ""

    -- find the pid and kill it
    if my_cmd == "traceroute" then
        local pid = found_pid(my_cmd)
        if pid then
            luci.sys.call("kill -9 %q" % pid)
        end
    elseif my_cmd == "ping" then

        luci.sys.fork_call("echo 'FINISH' > " .. FIN_STATUS)

        local pid = found_pid(my_cmd)
        if pid then
            luci.sys.call("kill -2 %q" % pid)
        end

    end

    -- luci.sys.fork_call("lock -w " .. LOCK_PATH)

    my_result = read_from_File(my_path)

    if my_result == " " then
	    dbg("555")
        my_result = "There are no response from DNS.\n    please check the domain name or DNS.\n"
    end

    my_result = my_result .. my_cmd .. " is stopped. \n"

    return compact_data(types, my_ip, my_iface, my_count, my_pkt, my_timeout, my_ttl, "1", my_result)

end


local function stop_action(http_form)
	local form_data  = json.decode(http_form.data)
    local params     = form_data.params
	
    local types = params["type"] or ""
    local ret
    if types == "0" then
        ret = stop_cmd(http_form, "ping", PING_PATH)
    elseif types == "1" then
        ret = stop_cmd(http_form, "traceroute", TRACE_PATH)
    end

    return ret

end

local function get_default_value(http_form)
    local uci_r = uci.cursor()

    reset_cfg_data()

    local count    = uci_r:get("diagnostic", "params", "count") or 4
    local pktsize  = uci_r:get("diagnostic", "params", "pktsize") or 64
    local timeout  = uci_r:get("diagnostic", "params", "timeout") or 800
    local ttl      = uci_r:get("diagnostic", "params", "ttl") or 20
    local ipaddr   = uci_r:get("diagnostic", "params", "ipaddr") or ""
	local iface    = ""

    return compact_data(0, ipaddr, iface, count, pktsize, timeout, ttl, "", "The Router is ready.\n")
end

--- Dispatch table
local dispatch_tbl = {
    diag = {
        ["start"]    = {cb = start_action},
        ["stop"]     = {cb = stop_action},
        ["get"]     = {cb = get_default_value},
        ["continue"] = {cb = continue_action}
    }
}

function dispatch(http_form)
    return ctl.dispatch(dispatch_tbl, http_form)
end

function _index()
    return ctl._index(dispatch)
end

--- Module entrance
function index()
    entry({"admin", "diagnostic"}, call("_index")).leaf = true
end
