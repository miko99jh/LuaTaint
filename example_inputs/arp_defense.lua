--[[
Copyright (C) 2008-2015 Shenzhen TP-LINK Technologies Co.Ltd.

File:         arp_defense.lua
Details:    controller for firewall --> arp_defense webpage
Author:     Huang Zhenwei <huangzhenwei_w7043@tp-link.net>
Version:   1.0.0
Date:        14May2015
History:    14May2015    Huang Zhenwei    Create the file
                19May2015    Huang Zhenwei    Fix kernel arp cache update
				02Jun2015    Huang Zhenwei     Modify according to the new http form
				26Augest2015 Luo Pei      write start ip,end ip and iface into config file
]]--

module("luci.controller.admin.arp_defense", package.seeall)

local ctl = require "luci.model.controller"
local uci = require "luci.model.uci"
local sys = require "luci.sys"
local ip   = require "luci.ip"
local form = require "luci.tools.form"
local err = require "luci.tools.error"
local dbg = require "luci.tools.debug"
local nixio = require "nixio"
local userconfig   = require "luci.model.userconfig"
local uci_r = uci.cursor()
local op = 0
local cmd = {}
local arp_scan_cmd="/lib/arplist/arp_scan.sh"
local interface = nil
--[[
	to make sure 'enable' is either 'on' or 'off'
]]--

local function zone_get_zone_bydev(dev)
	local mycmd = ". /lib/zone/zone_api.sh; zone_get_iface_bydev " .. dev
	ff = io.popen(mycmd, "r")
	if not ff then
		return false
	end
	local ll = ff:read("*l")
	if not ll then
		return false
	end
	local iface = string.gsub(tostring(ll), "%s.*", "")

	mycmd = ". /lib/zone/zone_api.sh; zone_get_zone_byif " .. iface
	ff = io.popen(mycmd, "r")
	if not ff then
		return false
	end
	local ll = ff:read("*l")
	if not ll then
		return false
	end
	local ret = string.gsub(tostring(ll), "%s.*", "")
	return ret
end


local function on_off(val)
    local opt = { on = true, off = true }
    return opt[val]
end


local function reset_info()
	op = 0
	cmd = {}
end

local function get_ipmac_config()
	local rets={}

	uci_r:foreach("imb","imb_rule",
			function(section)
				rets[#rets+1] = {}
				rets[#rets].mac = section["mac"]
				rets[#rets].ipaddr =section["ipaddr"]
				rets[#rets].mac = string.lower(rets[#rets].mac)
				rets[#rets].mac = string.gsub(rets[#rets].mac,"-",":") --turn xx-xx-xx-xx-xx-xx to xx:xx:xx:xx:xx:xx
			end
		)
	return rets
end

function valid_same_subnet(ip1, ip2, netmask)
	local ip1_network = ip.IPv4(ip1, netmask):network()
	local ip2_network = ip.IPv4(ip2, netmask):network()
	
	return ip1_network:string() == ip2_network:string()
end


function valid_host_ip(ip_test, netmask)
	local ret = true
	local ip_cidr = ip.IPv4(ip_test, netmask)
	
	if ip_cidr:equal(ip_cidr:network()) or ip_cidr:equal(ip_cidr:broadcast()) then
		ret = false
	end
	
	return ret
end


function valid_target_ip(ip_l, ip_h)
	local ret = false
	local ip_l_cidr = ip.IPv4(ip_l, "255.255.255.0")
	local ip_h_cidr = ip.IPv4(ip_h, "255.255.255.0")
	
	if ip_l_cidr:network():string() == ip_h_cidr:network():string() then
		ret = ip_h_cidr:higher(ip_l_cidr) or ip_h_cidr:equal(ip_l_cidr);
	end
	
	return ret
end

local function get_scan_network_segment(http_form)
	local ret={}
	
	ret["ipstart"] = uci_r:get("arp_scan_range","settings","ipstart")
	ret["ipend"] = uci_r:get("arp_scan_range","settings","ipend")
	ret["iface"] = uci_r:get("arp_scan_range","settings","iface")
	
	return ret
end

function scan_network_segment(http_form)
	local ret = {}
	local form_data = luci.json.decode(http_form.data)
	local params = form_data.params
	local ip_start = params.ipstart
	local ip_end = params.ipend

	local iface = params.iface or ""
	
	local if_info = nixio.getifaddrs()
	local valid_flag = false
	local ifaddr = nil
	local ifnetmask = nil

	--dbg("enter in arp_scan_result")

	if not valid_target_ip(ip_start, ip_end) then
		return false, err.ERR_FIREWALL_TABLE_ITEM_NOT_VALID
	end
	
	ret.ip_start = ip_start
	ret.ip_end = ip_end
	
	for _, e in ipairs(if_info) do
		if e.family == "inet" and e.flags.up then
			--dbg("if info", e.name, e.family, e.addr, e.netmask, e.prefix, e.flags.up)
			if valid_same_subnet(ip_start, e.addr, e.netmask) and 
					valid_same_subnet(ip_end, e.addr, e.netmask) then
				if iface == "" or iface == e.name then
					iface = e.name
					ifaddr = e.addr
					ifnetmask = e.netmask
					valid_flag = true
					break
				end
			end	
		end
	end
	
	if valid_flag then
		op = 1
		uci_r:set("arp_scan_range","settings","ipstart",ip_start)
		uci_r:set("arp_scan_range","settings","ipend",ip_end)
		uci_r:set("arp_scan_range","settings","iface",iface)
	--	uci_r:set("arp_scan_range","settings","ifaddr",ifaddr)
	--	uci_r:set("arp_scan_range","settings","ifnetmask",ifnetmask)
		if not uci_r:commit("arp_scan_range") then
			return false, err.ERR_COM_UCI_COMMIT
		end
		local cmd = string.format("/lib/devmngr/scan.sh %s %s %s /tmp/tmp_scan_result",ip_start,ip_end,iface)
		sys.fork_exec(cmd)
		userconfig.cfg_modify();
		return true
	else
		return false, err.ERR_FIREWALL_IPRANGE_NOT_WIRHIN_DEVICE
	end
	
	--ret.iface = iface
	
	--return ret
end

local function Is_ip_in_range(arp_ip)
	local start_ip = uci_r:get("arp_scan_range","settings","ipstart")
	local end_ip = uci_r:get("arp_scan_range","settings","ipend")
	
	local ip_l_cidr = ip.IPv4(start_ip)
	local ip_h_cidr = ip.IPv4(end_ip)
	local arp_ip_cidr = ip.IPv4(arp_ip)
	ret=(arp_ip_cidr:higher(ip_l_cidr) or arp_ip_cidr:equal(ip_l_cidr)) and (arp_ip_cidr:lower(ip_h_cidr) or arp_ip_cidr:equal(ip_h_cidr))
	return ret
end

function get_arp_scan_result()
	
	local interface_for_return = ""
	local data = {}
	--local if_info = nixio.getifaddrs()
	
	local interface = uci_r:get("arp_scan_range","settings","iface")

	local line=""
	local index = 1

	interface_for_return=zone_get_zone_bydev(interface)
	for line in io.lines("/tmp/tmp_scan_result") do

		if index == 1 then
			data[#data+1] = {}
			data[#data].ip = line
			index = 2
		elseif index==2 then
			index =3
			data[#data].mac = string.upper(line)
			data[#data].mac = string.gsub(data[#data].mac,":","-")
		else
			index = 1
			data[#data].state = line
		end
		data[#data].interface = interface_for_return
	end
	
	return data
end

local xx=0
function check_scan_progress()
	local ret={}
	ret["percent"] = xx
	xx = xx+10
	return ret
end

function read_imb_pass_settings()
	local ret = {}
	ret.imb_pass = uci_r:get("arp_defense", "settings", "imb_pass")
	if not ret.imb_pass then
		return false, err.ERR_COM_TABLE_ITEM_UCI_GET
	end
	
	return ret
end


function write_imb_pass_settings(http_form)
    local ret = {}
	local form_data = luci.json.decode(http_form.data)
	local params = form_data.params
	local imb_pass = params.imb_pass
    
	if not on_off(imb_pass) then
		return false, err.ERR_FIREWALL_TABLE_ITEM_NOT_VALID
    end
	
    uci_r:set("arp_defense", "settings", "imb_pass", imb_pass)
    local res = uci_r:commit("arp_defense")
	if not res then
		return false, err.ERR_COM_UCI_COMMIT
	end
	
	op = 2
	cmd[#cmd + 1] = string.format("/etc/init.d/arp_defense reload")
	userconfig.cfg_modify();
	ret.imb_pass = imb_pass
    return ret
end


function read_garp_settings()
	local ret = {}
	ret.garp = uci_r:get("arp_defense", "settings", "garp")
	if not ret.garp then
		return false, err.ERR_COM_TABLE_ITEM_UCI_GET
	end
	
	return ret
end


function write_garp_settings(http_form)
    local ret = {}
	local form_data = luci.json.decode(http_form.data)
	local params = form_data.params
	local garp = params.garp
    
	if not on_off(garp) then
		return false, err.ERR_FIREWALL_TABLE_ITEM_NOT_VALID
    end
	
    uci_r:set("arp_defense", "settings", "garp", garp)
    local res = uci_r:commit("arp_defense")
	if not res then
		return false, err.ERR_COM_UCI_COMMIT
	end
	
	op = 3
	if garp == "on" then
		cmd[#cmd + 1] = string.format("cp /lib/modules/files/50-arp_garp /etc/modules.d/")
		cmd[#cmd + 1] = string.format("insmod /lib/modules/$(uname -r)/arp_garp.ko")
	else
		cmd[#cmd + 1] = string.format("rm -f /etc/modules.d/50-arp_garp")
		cmd[#cmd + 1] = string.format("rmmod arp_garp")
	end
	userconfig.cfg_modify();
	ret.garp = garp
    return ret
end


--[[
	reserve for method 'do'
]]--
function do_func(http_form)
	--temporary do nothing
end

local SCAN_MAX = 256 

function scan_max_rules()
    return { ["max_rules"] = uci_r:get_profile("imb", "arp_scan_max") or SCAN_MAX }
end


--[[
    dispatch table
]]--
local dispatch_tbl = {
    arp_scan = {
        ["set"]  = { cb  = scan_network_segment},
		["get"] = { cb = get_scan_network_segment,
						others = scan_max_rules },
		["scan_check"] = { cb = check_scan_progress}
    },
	arp_scan_result = {	["get"] = { cb = get_arp_scan_result ,
        				others = scan_max_rules}
	},
    arp_imb_pass = {
        ["get"]  = { cb  = read_imb_pass_settings },
        ["set"] = { cb  = write_imb_pass_settings },
		["do"] = { cb = do_func },
    },

    arp_garp = {
        ["get"]   = { cb  = read_garp_settings }, 
        ["set"] = { cb  = write_garp_settings },
		["do"] = { cb = do_func },
    }
}


--[[
    dispatch function
]]--
function dispatch(http_form)
    local function hook_cb(success, action)
    	--rebind ip & mac
    	--[[if op == 10 then
    		local interface = uci_r:get("arp_scan_range","settings","iface")
			local start_ip = uci_r:get("arp_scan_range","settings","ipstart")
			local end_ip = uci_r:get("arp_scan_range","settings","ipend")
			local cmd = string.format("imb_read -r %s %s %s",start_ip,end_ip,interface)
			sys.fork_exec(cmd)
    	end]]
		if success then
			if op == 1 then    --arp scan
				if table.getn(cmd) ~=3 then
					return false
				end
				for _, j in ipairs(cmd) do
					--dbg("cmd=",j)
					sys.fork_exec(j)
				end
			elseif op == 2 then    --write imb pass
				if table.getn(cmd) ~=1 then
					return false
				end
				--dbg("cmd=", cmd[1])
				sys.fork_exec(cmd[1])
			elseif op == 3 then    --write garp
				if table.getn(cmd) ~=2 then
					return false
				end
				for _, j in ipairs(cmd) do
					--dbg("cmd=",j)
					sys.fork_exec(j)
				end
			end
		end
		
		reset_info()
        return true
    end
    return ctl.dispatch(dispatch_tbl, http_form, {post_hook = hook_cb})
end


--[[
    _index function
]]--
function _index()
    return ctl._index(dispatch)
end


--[[
    index function
]]--
function index()
    entry({"admin", "arp_defense"}, call("_index")).leaf = true
end