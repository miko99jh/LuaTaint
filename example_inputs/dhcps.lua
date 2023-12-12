--[[
Copyright(c) 2008-2015 Shenzhen TP-LINK Technologies Co.Ltd.

File    :  dhcp_server.lua
Details :  
Version :  1.0.0
Author  :  Yuan Fengjia 
History :  30May2015  Yuan Fengjia Create the file
]]--

local uci    = require "luci.model.uci"
local sys    = require "luci.sys"
local form   = require "luci.tools.form"
local dtype  = require "luci.tools.datatypes"
local nw     = require "luci.model.nwcache"
local ipm    = require "luci.ip"
local json_m = require "luci.json"
local error  = require "luci.tools.error"
local utl    = require "luci.util"
local reference_m = require "luci.model.reference"
local userconfig = require "luci.model.userconfig"
local ifs    = require "luci.model.interfaces".ifs()
require("luci.ip")

local dbg   = require "luci.tools.debug"

module("luci.controller.admin.dhcps", package.seeall)

local DHCPS_MAX_RSVD_HOST = 1024
local DHCPS_MAX_SERVER = 80
local DHCPS_SHELL = "/etc/init.d/dnsmasq"
local RELOAD = "reload"
local RESTART = "restart"
local CONFIG_NAME  = "dhcp"
local nwreloadcmd      = "/etc/init.d/network reload"
local nwrestartcmd     = "/etc/init.d/network restart"

local uci_r = uci.cursor()
form = form.Form(uci_r)
local refer_m = reference_m.REF_INST()

local DHCPS_KEYS = {
    server = {"enable", "interface", "external_port", "protocol", "ipaddr"},
    static = {"enable", "interface", "trigger_protocol", "external_protocol"}
}

local function zone_get_iface_bydev(t)
    local devices 

    local cmd = ". /lib/zone/zone_api.sh; zone_get_iface_bydev " .. t
    local ff = io.popen(cmd, "r");
    if not ff then
        return devices
    end

    local l = ff:read("*l")
    return l
end

local function recalc_pool()
    local lan_ip  = uci_r:get("network", "lan", "ipaddr")
    local netmask = uci_r:get("network", "lan", "netmask")

    local cidr_ip = ipm.IPv4(lan_ip, netmask):network()
    local cidr_broad = ipm.IPv4(lan_ip, netmask):broadcast()

	dbg("########000000000000000")
    if not cidr_ip or not cidr_broad then
        return false
    else
        if tonumber((cidr_broad - cidr_ip)[2][2]) <128 then
            local new_limit = (cidr_broad - cidr_ip)
            new_limit = tonumber(new_limit[2][2]) - 2
			new_limit = (new_limit>100) and 100 or new_limit
			--dbg("###new limit##",new_limit)
            uci_r:set("dhcp", "lan", "start", 2)
            uci_r:set("dhcp", "lan", "limit", new_limit)
			uci_r:commit("dhcp")
			return true
        else
            -- Use the default ip pool range
            uci_r:set("dhcp", "lan", "start", 100)
            uci_r:set("dhcp", "lan", "limit", 100)
			uci_r:commit("dhcp")
            return true
        end
    end 
    return false
end

local function calc_ipaddr_pool(iface)
    --dbg("calc_ipaddr_pool")
    uci_r:load("network")
    local nw  = nw.init()
	--dbg("calc_ipaddr_pool1")
    local net = nw:get_network(iface)
	--dbg("net:",net)
	--dbg.dumptable(net)
    local lan_ip = net:ipaddr()
    local netmask = net:netmask()
	--dbg("lan_ip:",lan_ip)
	--dbg("netmask:",netmask)

    local start = uci_r:get("dhcp", iface, "start")
    local limit = uci_r:get("dhcp", iface, "limit")
	--dbg("start:",start)
	--dbg("limit:",limit)
    local cidr_ip = ipm.IPv4(lan_ip, netmask):network()

	--dbg("cidr_ip:",cidr_ip)
	--dbg.dumptable(cidr_ip)
    if not cidr_ip then
	    --dbg("calc_ipaddr_pool4")
        return false
    else
	    --dbg("1111")
        local start_ip = cidr_ip + tonumber(start)
		--dbg("start_ip:",start_ip)
        local end_ip
        --dbg("222")
        if tonumber(limit) > 0 
        then 
            end_ip = start_ip + (tonumber(limit) - 1)
        else 
            end_ip = start_ip + tonumber(limit)
        end
		 --dbg("333")
        local ippool = {
            startip = start_ip:string(),
            endip   = end_ip:string()
        }

		--dbg("calc_ipaddr_pool3")
        return ippool
    end
end

local function calc_pool_region(startip, endip,iface)
	
    uci_r:load("network")
    local lanip  = uci_r:get("network", iface, "ipaddr")
    local netmask = uci_r:get("network", iface, "netmask")

	--if nil == lanip and netmask == nil then
	--    lanip = startip
	--	netmask = "255.255.255.0"
	--end
	
    local network = ipm.IPv4(lanip, netmask):network() -- get network address
    local broadcast = ipm.IPv4(lanip, netmask):broadcast() -- get broadcast address

	--dbg("lanip:",lanip)
	--dbg("netmask:",netmask)
	
	--dbg("network:",network)
	--dbg.dumptable(network)
	--dbg("broadcast:",broadcast)
	
    local cidr_startip = ipm.IPv4(startip, netmask)
    local cidr_endip   = ipm.IPv4(endip, netmask)
    
    if cidr_startip:network():string() ~= network:string() or
           cidr_endip:network():string() ~= network:string() 
    then 
        -- dbg('cidr_startip: ',cidr_startip:network():string())
        -- dbg('cidr_endip: ',cidr_endip:network():string())
        -- dbg('network: ',network():string())

        dbg('not the same subnet')

        return false -- Not the same subnet
    end

    local a = string.match(endip, ".(%d+)$")
    local b = string.match(broadcast:string(), ".(%d+)$")
    --[[if tonumber(a) > tonumber(b) then
        return false -- Invalid ip pool range
    end]]--
	if broadcast:lower(cidr_endip) or broadcast:equal(cidr_endip) then
		dbg("---fail to compare broadcast ip: ", broadcast:string())
		return false
    end

    local start = cidr_startip - network     -- start = startip - network
    local limit = cidr_endip - startip       -- limit = endip - startip
	--dbg("start:",start)
	--dbg("limit:",limit)
    if not start or not limit then
        dbg('not start or not limit')
        return false
    end
    
    -- plus one here for address pool
    local new_limit = limit[2][2] + 1
    return start[2][2], new_limit
end

local function set_default_dhcp_options()
	local default_start=100
	local default_limit=100
    uci_r:load("dhcp")
	--dbg("---in set default dhcp options--")
    uci_r:set("dhcp", "lan", "start", default_start)
    uci_r:set("dhcp", "lan", "limit", default_limit)
	--dbg("---in set default dhcp options--")
    uci_r:commit("dhcp")
	return true
end


local function get_dhcp_options(iface)
    --dbg("iface:",iface)
    local options = {}
	local data = {}
	
	options = uci_r:get("dhcp", iface, "dhcp_option")

    if not options then
        return false
    end
	
	--dbg("options:",options)

    for _, op in ipairs(options) do
        local op_code = op:match("(%d+),")
        if op_code == "3" then
            data.gateway = op:match(",(.+)") or ""
        elseif op_code == "6" then
            local op1, op2 = op:match(",(.+),%s*(.+)")
            data.dns = {op1, op2} 
        elseif op_code == "15" then
            data.domain = op:match(",(.+)") or ""
        elseif op_code == "60" then             
			data.manufacturer = op:match(",(.+)") or ""        
		elseif op_code == "138" then             
			data.ac_ip = op:match(",(.+)") or ""        
		end
    end

    return data
end

-- Update the options of dhcp server
function dhcp_opt_update(ipaddr)
    if not dtype.ipaddr(ipaddr) then
        return false
    end

    local chg = recalc_pool() -- Reset start ipaddr and range limit

    local options = get_dhcp_options("lan")
    if options then
        -- Only lan ip address different form current dhcps gateway, will update
        if ipaddr ~= options.gateway then
            uci_r:delete("dhcp", "lan", "dhcp_option")  
            uci_r:set_list("dhcp", "lan", "dhcp_option", "3," .. ipaddr)
            if options.dns then
                local pri_dns, snd_dns
                pri_dns = options.dns[1] and options.dns[1] or "0.0.0.0"
                snd_dns = options.dns[2] and options.dns[2] or "0.0.0.0"
                if pri_dns ~= "0.0.0.0" or snd_dns ~= "0.0.0.0" then
                    uci_r:set_list("dhcp", "lan", "dhcp_option", "6," .. pri_dns .. "," .. snd_dns)
                end
            end
            if options.domain then
                uci_r:set_list("dhcp", "lan", "dhcp_option", "15," .. options.domain) 
            end
            chg = true      
        end
    end

    if chg then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
    end
end


function get_max_servers()
    return { ["max_rules"] = uci_r:get_profile("dhcps", "server_max") or DHCPS_MAX_SERVER }
end

function dhcp_server_max_check()
    local max = get_max_servers()
    local cur = form:count("dhcp", "dhcp")
    
    if cur >= max.max_rules then
        return false
    end
    
    return true
end

--- Get dhcp server list from configuration
function get_dhcp_settings2(iface)
    --dbg("iface:",iface)
    local ippool = calc_ipaddr_pool(iface)
	--dbg("ippool:",ippool)
    local options = get_dhcp_options(iface)
	--dbg("options:",options)
    local settings = {}

    local leasetime = uci_r:get("dhcp", iface, "leasetime")
    local num, unit = leasetime:match("(%d+)(%l)$")

    if unit == "h" then
        num = tonumber(num) * 60
    end

    settings.leasetime = tostring(num)
    settings.ipaddr_start = ippool.startip
    settings.ipaddr_end   = ippool.endip
    if options then
        settings.gateway = options.gateway and options.gateway or ""
        settings.domain  = options.domain and options.domain or ""
        settings.option60 = options.manufacturer or ""        
		settings.option138 = options.ac_ip or ""        
		if options.dns then
            settings.pri_dns = options.dns[1] and options.dns[1] or ""
            settings.pri_dns = settings.pri_dns == "0.0.0.0" and "" or settings.pri_dns
            settings.snd_dns = options.dns[2] and options.dns[2] or ""
            settings.snd_dns = settings.snd_dns == "0.0.0.0" and "" or settings.snd_dns
        else
            settings.pri_dns = ""
            settings.snd_dns = ""
        end
    else
        settings.gateway = ""
        settings.domain  = ""
        settings.pri_dns = ""
        settings.snd_dns = ""
        settings.option60 = ""        
		settings.option138 = ""    
	end

    settings.enable  = ("1" == uci_r:get("dhcp", iface, "ignore")) and "off" or "on"

    return settings
end

function load_dhcp_servers()
    local dhcp_servers = {}

    local servers = {}
    uci_r:foreach("dhcp", "dhcp",
        function(section)
            servers[#servers + 1] = uci_r:get_all("dhcp", section[".name"])
        end
    )

	--dbg("servers:",servers)
	--dbg.dumptable(servers)
	
    for k, rt in ipairs(servers) do
		local settings = {}
		settings = get_dhcp_settings2(rt.interface)
		--dbg("settings:",settings)
		--dbg.dumptable(settings)
		
        local result = {}
        result.interface   = rt.interface
        result.addrtype = rt.addrtype
		result.ippool = rt.ippool
		result.ipaddr_start = settings.ipaddr_start
		result.ipaddr_end = settings.ipaddr_end
		result.leasetime = settings.leasetime
		result.gateway = settings.gateway
		result.domain = settings.domain
		result.pri_dns = settings.pri_dns
		result.snd_dns = settings.snd_dns
        result.enable = (settings.enable == "on") and "on" or "off"
        dhcp_servers[k] = result
    end

    return dhcp_servers
end

function load_ret_server(rt)
	local settings = {}
	settings = get_dhcp_settings2(rt.interface)
		
    local result = {}
    result.interface   = rt.interface
	result.addrtype = rt.addrtype
	result.ippool = rt.ippool
	result.ipaddr_start = settings.ipaddr_start
	result.ipaddr_end = settings.ipaddr_end
	result.leasetime = settings.leasetime
	result.gateway = settings.gateway
	result.domain = settings.domain
	result.pri_dns = settings.pri_dns
	result.snd_dns = settings.snd_dns
	result.enable = (settings.enable == "on") and "on" or "off"

    return result
end

-- the process is OK except that when type is ippool, a ref has to added
function insert_dhcp_server(http_form)
    local form_data = json_m.decode(http_form.data)
    local params = form_data.params
    local new  = params.new or false
	
	local start
	local limit
	local ignore
	local leasetime
	local dynamicdhcp = 1
	local gateway
	local domain
	
	local index = params.index or 0
    
    if not new and type(new) ~= "table" then
        return false,error.ERR_DHCPS_INVALID_PARAMS
    end
	
	--dbg("new:",new)
	--dbg.dumptable(new)

    if not dhcp_server_max_check() then
        return false,error.ERR_DHCPS_MAX_LIMIT
    end

	if new.addrtype == "ippool" then
	    if not new.ippool then
		    return false,error.ERR_DHCPS_IPPOOL_INVALID
		end
      --  new.ipaddr_start = new.ipaddr_start_hidden
      --  new.ipaddr_end = new.ipaddr_end_hidden
	else
	    if not new.ipaddr_start then
            return false, error.ERR_DHCPS_STARTIP_BLANK
        end
	end
    new.ipaddr_start_hidden = nil
    new.ipaddr_end_hidden = nil
	start, limit = calc_pool_region(new.ipaddr_start, new.ipaddr_end,new.interface)
    if not start then
        return false, error.ERR_DHCPS_POOL_INVALID
    end

	
	if new.enable == "on" then
        ignore = 0
    else
        ignore = 1
    end
	
	leasetime = (tonumber(new.leasetime) > 2880) and "2880" or new.leasetime
	--dbg("leasetime:",leasetime)
	leasetime = leasetime .. "m"
	--dbg("leasetime:",leasetime)
	
	if dtype.ipaddr(new.gateway) then 
        gateway = "3," ..new.gateway
    end
	
	local pri_dns   = new.pri_dns or "0.0.0.0"
    local snd_dns   = new.snd_dns or "0.0.0.0"
	local dns
	pri_dns = (pri_dns == "") and "0.0.0.0" or pri_dns
    snd_dns = (snd_dns == "") and "0.0.0.0" or snd_dns
	if dtype.ipaddr(pri_dns) and dtype.ipaddr(snd_dns) then 
       dns = "6," .. pri_dns .. "," .. snd_dns
    end
	
	domain = new.domain
	if dtype.host(domain) then
        domain = "15," .. domain
    end
	
	local data = {}
	data.interface = new.interface
	data.addrtype = new.addrtype
	if new.ippool then 
	    data.ippool = new.ippool
	end
	data.ignore = ignore
	data.leasetime = leasetime
	data.start = start
	data.limit = limit
	data.dynamicdhcp = dynamicdhcp
	--dbg("gateway:",gateway)
	local dhcp_option = {}
	
	local i = 1
	if nil ~= gateway then
	    dhcp_option[i] = gateway
		i=i+1
	end
	--dbg("dns:",dns)
	if nil ~= dns then
	    dhcp_option[i] = dns
		i=i+1
	end
	--dbg("domain:",domain)
	if nil ~= domain then
	    dhcp_option[i] = domain
		i=i+1
	end
	
	--dhcp_option[1]=gateway
    --dhcp_option[2]=dns
    --dhcp_option[3]=domain	
    
	data.dhcp_option =  dhcp_option
	--dbg("dhcp_option3:",data.dhcp_option)
	
	--dbg("data:",data)
	--dbg.dumptable(data)

    if not ifs.update_if_reference(new.interface, 1) then
        return false, error.ERR_COM_ADD_REFERENCE_FAILED
    end
	
    local ret = form:insert_section("dhcp", "dhcp", data,index,data.interface)
	--dbg("ret:",ret)
    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
		--dbg("ret:",ret)
		--dbg.dumptable(ret)
		local ret_data = load_ret_server(ret)
        if new.ippool then
            refer_m:update(1,new.ippool)
        end
        return ret_data
    else
        return false,error.ERR_COM_TABLE_ITEM_UCI_ADD
    end
end

function wizard_insert_dhcp_server(input)

    local new  = input or false

    local start
    local limit
    local ignore
    local leasetime
    local dynamicdhcp = 1
    local gateway
    local domain
     uci_r:load(CONFIG_NAME)
    
    local index = form:count(CONFIG_NAME, "dhcp");
    --dbg('cur dhcp itemNum : ',index)
    
    if not new and type(new) ~= "table" then
        return false,error.ERR_DHCPS_INVALID_PARAMS
    end
    
    --dbg("new:",new)
    --dbg.dumptable(new)

    if not dhcp_server_max_check() then
        return false,error.ERR_DHCPS_MAX_LIMIT
    end

    if new.addrtype == "ippool" then
        if not new.ippool then
            return false,error.ERR_DHCPS_IPPOOL_INVALID
        end
      --  new.ipaddr_start = new.ipaddr_start_hidden
      --  new.ipaddr_end = new.ipaddr_end_hidden
    else
        if not new.ipaddr_start then
            return false, error.ERR_DHCPS_STARTIP_BLANK
        end
    end
    new.ipaddr_start_hidden = nil
    new.ipaddr_end_hidden = nil
    start, limit = calc_pool_region(new.ipaddr_start, new.ipaddr_end,new.interface)
    if not start then
        return false, error.ERR_DHCPS_POOL_INVALID
    end

    
    if new.enable == "on" then
        ignore = 0
    else
        ignore = 1
    end
    
    leasetime = (tonumber(new.leasetime) > 2880) and "2880" or new.leasetime
    --dbg("leasetime:",leasetime)
    leasetime = leasetime .. "m"
    --dbg("leasetime:",leasetime)
    
    if dtype.ipaddr(new.gateway) then 
        gateway = "3," ..new.gateway
    end
    
    local pri_dns   = new.pri_dns or "0.0.0.0"
    local snd_dns   = new.snd_dns or "0.0.0.0"
    local dns
    pri_dns = (pri_dns == "") and "0.0.0.0" or pri_dns
    snd_dns = (snd_dns == "") and "0.0.0.0" or snd_dns
    if dtype.ipaddr(pri_dns) and dtype.ipaddr(snd_dns) then 
       dns = "6," .. pri_dns .. "," .. snd_dns
    end
    
    domain = new.domain
    if dtype.host(domain) then
        domain = "15," .. domain
    end
    
    local data = {}
    data.interface = new.interface
    data.addrtype = new.addrtype
    if new.ippool then 
        data.ippool = new.ippool
    end
    data.ignore = ignore
    data.leasetime = leasetime
    data.start = start
    data.limit = limit
    data.dynamicdhcp = dynamicdhcp
    --dbg("gateway:",gateway)
    local dhcp_option = {}
    
    local i = 1
    if nil ~= gateway then
        dhcp_option[i] = gateway
        i=i+1
    end
    --dbg("dns:",dns)
    if nil ~= dns then
        dhcp_option[i] = dns
        i=i+1
    end
    --dbg("domain:",domain)
    if nil ~= domain then
        dhcp_option[i] = domain
        i=i+1
    end
    
    --dhcp_option[1]=gateway
    --dhcp_option[2]=dns
    --dhcp_option[3]=domain 
    
    data.dhcp_option =  dhcp_option
    --dbg("dhcp_option3:",data.dhcp_option)
    
    --dbg("data:",data)
    --dbg.dumptable(data)
    uci_r:load("network")

    if not ifs.update_if_reference(new.interface, 1) then
        return false, error.ERR_COM_ADD_REFERENCE_FAILED
    end
    
    local ret = form:insert_section("dhcp", "dhcp", data,index,data.interface)
    --dbg("ret:",ret)
    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
        --dbg("ret:",ret)
        --dbg.dumptable(ret)
        local ret_data = load_ret_server(ret)
        if new.ippool then
            refer_m:update(1,new.ippool)
        end
        return ret_data
    else
        return false,error.ERR_COM_TABLE_ITEM_UCI_ADD
    end
end

-- when increase the ref to the ippool,old_type & new_type are both needed
function update_dhcp_server(http_form)
	local form_data = json_m.decode(http_form.data)
	local params = form_data.params
	local old = params.old or false
	local new = params.new or false
    local count = 0
    local index = params.index or 0
    local old_addrtype
    local old_ippoolname = nil

    if not new and type(new) ~= "table" or
        not old and type(old) ~= "table" then
        return false,ERR_DHCPS_INVALID_PARAMS
    end
	
    uci_r:foreach("dhcp","dhcp",
        function(section)
                if tonumber(index) == count then
                    old_addrtype = section["addrtype"]
                    if old_addrtype == "ippool" then
                        old_ippoolname = section["ippool"]
                    end
                 --   dbg("old_addrtype:",old_addrtype)
                 --   dbg("old_ippoolname",old_ippoolname)
                end
                count = count+1
        end
        )
	uci_r:delete("dhcp",old.interface)
	
	--local old_data
	--old_data = uci_r:get("dhcp",old.interface)
	--dbg("old_data:",old_data)
	--dbg.dumptable(old_data)
	
	local start
	local limit
	local ignore
	local leasetime
	local dynamicdhcp = 1
	local gateway
	local domain
	
    if not new and type(new) ~= "table" then
        return false,error.ERR_DHCPS_INVALID_PARAMS
    end

    --if not dhcp_server_max_check() then
    --    return false,error.ERR_DHCPS_MAX_LIMIT
    --end

	if new.addrtype == "ippool" then
	    if not new.ippool then
		    return false,error.ERR_DHCPS_IPPOOL_INVALID
		end
     --   new.ipaddr_start = new.ipaddr_start_hidden
      --  new.ipaddr_end = new.ipaddr_end_hidden
	else
	    if not new.ipaddr_start then
            return false, error.ERR_DHCPS_STARTIP_BLANK
        end
	end
    new.ipaddr_start_hidden = nil
    new.ipaddr_end_hidden = nil
    new.interface = old.interface
	start, limit = calc_pool_region(new.ipaddr_start, new.ipaddr_end,new.interface)
    if not start then
        return false, error.ERR_DHCPS_POOL_INVALID
    end
	
	if new.enable == "on" then
        ignore = 0
    else
        ignore = 1
    end
	
	leasetime = (tonumber(new.leasetime) > 2880) and "2880" or new.leasetime
	leasetime = leasetime .. "m"
	
	if dtype.ipaddr(new.gateway) then 
        gateway = "3," ..new.gateway
    end
	
	local pri_dns   = new.pri_dns or "0.0.0.0"
    local snd_dns   = new.snd_dns or "0.0.0.0"
	local dns
	pri_dns = (pri_dns == "") and "0.0.0.0" or pri_dns
    snd_dns = (snd_dns == "") and "0.0.0.0" or snd_dns
	if dtype.ipaddr(pri_dns) and dtype.ipaddr(snd_dns) then 
        --if pri_dns ~= "0.0.0.0" and snd_dns ~= "0.0.0.0"then
		--   dns = "6"
		--end
		--if pri_dns ~= "0.0.0.0" then
		--    dns = dns .. "," .. pri_dns 
		--end
		--if snd_dns ~= "0.0.0.0" then
		--    dns = dns .. "," .. snd_dns
		--end
		dns = "6," .. pri_dns .. "," .. snd_dns
    end
	
	domain = new.domain
	if dtype.host(domain) then
        domain = "15," .. domain
    end
	
	local data = {}
	data.interface = new.interface
	data.addrtype = new.addrtype
	if new.ippool then 
	    data.ippool = new.ippool
	end
	data.ignore = ignore
	data.leasetime = leasetime
	data.start = start
	data.limit = limit
	data.dynamicdhcp = dynamicdhcp
	local dhcp_option = {}
	
	local i = 1
	if nil ~= gateway then
	    dhcp_option[i] = gateway
		i=i+1
	end
	--dbg("dns:",dns)
	if nil ~= dns then
	    dhcp_option[i] = dns
		i=i+1
	end
	--dbg("domain:",domain)
	if nil ~= domain then
	    dhcp_option[i] = domain
		i=i+1
	end
	
	--dhcp_option[1]=gateway
    --dhcp_option[2]=dns
    --dhcp_option[3]=domain	
    
	data.dhcp_option =  dhcp_option
	--dbg("dhcp_option3:",data.dhcp_option)
	
	--dbg("data:",data)
	--dbg.dumptable(data)
    if new.interface ~= old.interface then
        if not ifs.update_if_reference(new.inteface, 1) then
            return false, error.ERR_COM_ADD_REFERENCE_FAILED
        end 
        if not ifs.update_if_reference(old.interface, 0) then
            return false, error.ERR_COM_DEL_REFERENCE_FAILED
        end
    end
	
	local ret = form:insert_section("dhcp", "dhcp", data,index,data.interface)
    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
		local ret_data = load_ret_server(ret)

        if old_addrtype == "ippool" and old_ippoolname ~= nil then
            refer_m:update(0,old_ippoolname)
        end

        if new.addrtype == "ippool" then
            refer_m:update(1,new.ippool)
        end
        return ret_data
    else
        return false,error.ERR_COM_TABLE_ITEM_UCI_UPDATE
    end
end

function update_dhcp_server2(http_form)
	local form_data = json_m.decode(http_form.data)
	local params = form_data.params

	uci_r:delete("dhcp","lan")
	
	--local old_data
	--old_data = uci_r:get("dhcp",old.interface)
	--dbg("old_data:",old_data)
	--dbg.dumptable(old_data)
	
	local start
	local limit
	local ignore
	local leasetime
	local dynamicdhcp = 1
	local gateway
	local domain
    local option60    
	local option138


	if params.addrtype == "ippool" then
	    if not params.ippool then
		    return false,error.ERR_DHCPS_IPPOOL_INVALID
		end
	else
	    if not params.ipaddr_start then
            return false, error.ERR_DHCPS_STARTIP_BLANK
        end
	end
	
    params.ipaddr_start_hidden = nil
    params.ipaddr_end_hidden = nil
	start, limit = calc_pool_region(params.ipaddr_start, params.ipaddr_end,"lan")
    if not start then
        return false, error.ERR_DHCPS_POOL_INVALID
    end
	
	if params.enable == "on" then
        ignore = 0
    else
        ignore = 1
    end
	
	leasetime = (tonumber(params.leasetime) > 2880) and "2880" or params.leasetime
	leasetime = leasetime .. "m"
	
	if dtype.ipaddr(params.gateway) then 
        gateway = "3," ..params.gateway
    end
	
	local pri_dns   = params.pri_dns or "0.0.0.0"
    local snd_dns   = params.snd_dns or "0.0.0.0"
	local dns
	pri_dns = (pri_dns == "") and "0.0.0.0" or pri_dns
    snd_dns = (snd_dns == "") and "0.0.0.0" or snd_dns
	if dtype.ipaddr(pri_dns) and dtype.ipaddr(snd_dns) then 
		dns = "6," .. pri_dns .. "," .. snd_dns
    end
	
	domain = params.domain
	if dtype.host(domain) or (domain == nil or domain == '')then
        domain = "15," .. domain
    end
    option60 = params.option60    
	option138 = params.option138	
	local data = {}
	data.interface = "lan"
	data.addrtype = "iprange"
	--if params.ippool then 
	--    data.ippool = params.ippool
	--end
	data.ignore = ignore
	data.leasetime = leasetime
	data.start = start
	data.limit = limit
	data.dynamicdhcp = dynamicdhcp
	local dhcp_option = {}
	
	local i = 1
	if nil ~= gateway then
	    dhcp_option[i] = gateway
		i=i+1
	end
	--dbg("dns:",dns)
	if nil ~= dns then
	    dhcp_option[i] = dns
		i=i+1
	end
	--dbg("domain:",domain)
	if nil ~= domain then
	    dhcp_option[i] = domain
		i=i+1
	end
    if nil ~= option60 and "" ~= option60 then        
		dhcp_option[i] = "60," .. option60        
		i=i+1                    end    
    if nil ~= option138 and "" ~= option138 then        
		dhcp_option[i] = "138," .. option138        
		i=i+1                    
	end	
	data.dhcp_option =  dhcp_option
	local ret = form:insert_section("dhcp", "dhcp", data,0,data.interface)
    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
		local ret_data = load_ret_server(ret)

        --if old_addrtype == "ippool" and old_ippoolname ~= nil then
        --    refer_m:update(0,old_ippoolname)
        --end

        --if new.addrtype == "ippool" then
        --    refer_m:update(1,new.ippool)
        --end
        return ret_data
    else
        return false,error.ERR_COM_TABLE_ITEM_UCI_UPDATE
    end
end

-- just need the types to be deleted
function remove_dhcp_server(http_form)
	local form_data=json_m.decode(http_form.data)
	local params = form_data.params
		
	local key = params.key or {}
	local index = params.index or {}
    local extrakey = params.extraKey or {}
	
	key = utl.split(key, ',')
	index = utl.split(index, ',')
    extrakey = utl.split(extrakey, ',')

    local indexes = (type(index)=="table") and index or {index}
    local tmp_ret = {}
    local old_addrtype = {}
    local old_ippoolname={}
    uci_r:foreach("dhcp","dhcp",
            function(section)
                --dbg("enter into remove here")
                old_addrtype[#old_addrtype+1] = section["addrtype"]
                if old_addrtype[#old_addrtype] == "ippool" then
                    old_ippoolname[#old_addrtype] = section["ippool"]  --could be nil or sth
                else
                    old_ippoolname[#old_addrtype] = nil
                end
            end
        )
    for _,j in pairs(indexes) do
        if old_addrtype[j+1] == "ippool" then
            tmp_ret[#tmp_ret+1] = old_ippoolname[j+1]
        end
    end

    if extrakey then
        for i, v in pairs(extrakey) do
            if not ifs.update_if_reference(v, 0) then
                return false, error.ERR_COM_DEL_REFERENCE_FAILED
            end
        end
    end

    local ret = form:delete("dhcp", "dhcp", key, index)

    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()

        for _,j in pairs(tmp_ret) do
            if j then  --this shall always be true
               -- dbg("name j=",j)
                refer_m:update(0,j)
            end
        end
        return ret
    else
        return false, error.ERR_COM_TABLE_ITEM_UCI_DEL
    end

end

--- Get static dhcp leases from configuration
function load_static_leases()
    local static_leases = {}

    local leases = {}
    -- get static routes info from network configuration
    uci_r:foreach("dhcp", "host",
        function(section)
            leases[#leases + 1] = uci_r:get_all("dhcp", section[".name"])
        end
    )

    for k, rt in ipairs(leases) do
        local data = {}
        local mac = (rt.mac):gsub(":", "-")
		data.interface = rt.interface
        data.ip   = rt.ip
        data.mac  = mac:upper()
        --data.name = rt.name
        data.note = rt.note
        data.enable = (rt.enable == "on") and "on" or "off"
        static_leases[k] = data
    end

    return static_leases
end

function check_static_entry(ipaddr)
    local ip
	local enable
	local find = "false"
	uci_r:foreach("dhcp", "host",
        function(section)
            ip = uci_r:get("dhcp", section[".name"],"ip")
			enable = uci_r:get("dhcp", section[".name"],"enable")
			if ip == ipaddr and enable == "on" then
				find = "true"
			end
        end
    )
	
	return find
end

local function dhcp_leases(interface)
	local rv = { }
	local nfs = require "nixio.fs"
	local family = 4
	local leasefile = "/var/dhcp." .. interface .. ".leases"

	local now
	local tmp
	local uptimefile="/proc/uptime"
	local fdtime=io.open(uptimefile, "r")
	if fdtime then
		local num = fdtime:read("*n")
		if not num then
			return rv
		else
			tmp = tonumber(num)
			now = math.floor(tmp)
		end
		fdtime:close()
	end

	local fd = io.open(leasefile, "r")
	if fd then
		while true do
			local ln = fd:read("*l")
			if not ln then
				break
			else
				local ts, mac, ip, name, duid = ln:match("^(%d+) (%S+) (%S+) (%S+) (%S+)")
				if ts and mac and ip and name and duid then
					if family == 4 and not ip:match(":") and ip ~= "0.0.0.0" then
					    local static = check_static_entry(ip)
						if static == "true" then
						    ts = 0;
						end
						rv[#rv+1] = {
							--expires  = os.difftime(tonumber(ts) or 0, os.time()),
							expires  = os.difftime(tonumber(ts) or 0, now),
							macaddr  = mac,
							ipaddr   = ip,
							hostname = (name ~= "*") and name
						}
						
						
					elseif family == 6 and ip:match(":") then
						rv[#rv+1] = {
							expires  = os.difftime(tonumber(ts) or 0, os.time()),
							ip6addr  = ip,
							duid     = (duid ~= "*") and duid,
							hostname = (name ~= "*") and name
						}
					end
				end
			end
		end
		fd:close()
	end

	return rv
end
--- Get dhcp active leases or client list
function load_active_leases()
    local client_list = {}

    local servers  = {}
    uci_r:foreach("dhcp", "dhcp",
        function(section)
            servers[#servers + 1] = uci_r:get_all("dhcp", section[".name"])
        end
    )
	
	local index=0
	for a,b in ipairs(servers) do
		local leases = dhcp_leases(b.interface)
		for k, rt in ipairs(leases) do
			local data = {}
			local macaddr  = (rt.macaddr):gsub(":", "-")
			data.macaddr   = macaddr:upper()
			data.name      = rt.hostname or "--" 
			data.ipaddr    = rt.ipaddr
			data.interface = b.interface

			if rt.expires < 0 then
				data.leasetime = "Permanent"
			else
				local hour = math.floor(rt.expires / 3600)
				local min = math.floor(rt.expires / 60) - hour * 60
				local sec = rt.expires - hour * 3600 - min * 60
				data.leasetime = hour .. ":" .. min .. ":" .. sec
			end
			
			index = index + 1
			client_list[index] = data
		end
    end  

    return client_list
end

function leases_flush()
    sys.fork_exec("rm -rf /tmp/dhcp.lan.leases")
    sys.fork_exec("/etc/init.d/dnsmasq restart")
end

function get_dhcp_settings()
    local ippool = calc_ipaddr_pool("lan")
    local options = get_dhcp_options("lan")
    local settings = {}

    local leasetime = uci_r:get("dhcp", "lan", "leasetime")
    local num, unit = leasetime:match("(%d+)(%l)$")

    if unit == "h" then
        num = tonumber(num) * 60
    end

    settings.leasetime = tostring(num)
    settings.ipaddr_start = ippool.startip
    settings.ipaddr_end   = ippool.endip
    if options then
        settings.gateway = options.gateway and options.gateway or ""
        settings.domain  = options.domain and options.domain or ""
        settings.option60 = options.manufacturer or ""        
		settings.option138 = options.ac_ip or ""                
		if options.dns then
            settings.pri_dns = options.dns[1] and options.dns[1] or ""
            settings.pri_dns = settings.pri_dns == "0.0.0.0" and "" or settings.pri_dns
            settings.snd_dns = options.dns[2] and options.dns[2] or ""
            settings.snd_dns = settings.snd_dns == "0.0.0.0" and "" or settings.snd_dns
        else
            settings.pri_dns = ""
            settings.snd_dns = ""
        end
    else
        settings.gateway = ""
        settings.domain  = ""
        settings.pri_dns = ""
        settings.snd_dns = ""
        settings.option60 = ""        
		settings.option138 = ""            
	end

    settings.enable  = ("1" == uci_r:get("dhcp", "lan", "ignore")) and "off" or "on"

    return settings
end

function set_dhcp_settings(http_form)
    -- get settings from webpage
    local form_data = json_m.decode(http_form.data)
    local params = form_data.params
    
    local leasetime = params.leasetime or ""
    local start_ip  = params.ipaddr_start
    local end_ip    = params.ipaddr_end or start_ip
    local status    = params.enable or ""
    local gateway   = params.gateway
    local domain    = params.domain
    local pri_dns   = params.pri_dns or "0.0.0.0"
    local snd_dns   = params.snd_dns or "0.0.0.0"
    
    if not start_ip then
        return false, error.ERR_DHCPS_STARTIP_BLANK
    end

    local start, limit = calc_pool_region(start_ip, end_ip,"lan")
    if not start then
        return false, error.ERR_DHCPS_POOL_INVALID
    end

    -- set settings to dhcp config file
    --local log = require("luci.model.log").Log(212)
    if status == "off" then
        --log(505)
        uci_r:set("dhcp", "lan", "ignore", "1")
    else
        --log(504)
        uci_r:set("dhcp", "lan", "ignore", "0")
    end
    leasetime = (tonumber(leasetime) > 2880) and "2880" or leasetime

    uci_r:set("dhcp", "lan", "leasetime", leasetime .. "m") -- leasetime unit is minutes
    uci_r:set("dhcp", "lan", "start", start)
    uci_r:set("dhcp", "lan", "limit", limit)
    uci_r:set("dhcp", "lan", "dynamicdhcp", "1") -- open dynamicdhcp by default
    uci_r:delete("dhcp", "lan", "dhcp_option")
   

    --if gateway == "" then
        --gateway = uci_r:get("network", "lan", "ipaddr")
    --end

    if dtype.ipaddr(gateway) then 
        uci_r:set_list("dhcp", "lan", "dhcp_option", "3," .. gateway) -- set dhcp option gateway
    end
    pri_dns = (pri_dns == "") and "0.0.0.0" or pri_dns
    snd_dns = (snd_dns == "") and "0.0.0.0" or snd_dns
    if dtype.ipaddr(pri_dns) and dtype.ipaddr(snd_dns) then 
        uci_r:set_list("dhcp", "lan", "dhcp_option", "6," .. pri_dns .. "," .. snd_dns) -- dhcp option dns server address
    end
    if dtype.host(domain) then
        uci_r:set_list("dhcp", "lan", "dhcp_option", "15," .. domain) -- set dhcp option default domain
    end
    uci_r:commit("dhcp")
	userconfig.cfg_modify()

    return get_dhcp_settings()

end

--- Update a dhcp static lease selected by UI
function update_static_lease(http_form)
		local form_data = json_m.decode(http_form.data)
		local params = form_data.params
		
		local old = params.old or false
		local new = params.new or false


    if not new and type(new) ~= "table" or
        not old and type(old) ~= "table" then
        return false,ERR_DHCPS_INVALID_PARAMS
    end

	--dbg("old:",old)
	--dbg.dumptable(old)
	--dbg("new:",new)
	--dbg.dumptable(new)
    old.mac = string.gsub(old.mac:upper(), "-", ":")
    new.mac = string.gsub(new.mac:upper(), "-", ":")
    if not dtype.macaddr(new.mac) or not dtype.ipaddr(new.ip) then
        return false,error.ERR_DHCPS_MAC_IP_INVALID
    end

    -- duplication detection
--[[
    if new.enable == "on" then
        if Imb:arplist_check_dup(new) then
            return false, error.ERR_DHCPS_IMB_DUPLICATION
        end
    end
]]--
    if new.interface ~= old.interface then
        if not ifs.update_if_reference(new.interface, 1) then
            return false, error.ERR_COM_ADD_REFERENCE_FAILED
        end
        if not ifs.update_if_reference(old.interface, 0) then
            return false, error.ERR_COM_DEL_REFERENCE_FAILED
        end
    end

    local ret = form:update("dhcp", "host", old, new, {"interface","ip", "mac"})
    if ret then ret.mac = string.gsub(ret.mac, ":", "-") end
    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
        return ret
    else
        return false, error.ERR_COM_TABLE_ITEM_UCI_UPDATE
    end
end

function get_max_static_lease()
    return { ["max_rules"] = uci_r:get_profile("dhcps", "rsvd_host_max") or DHCPS_MAX_RSVD_HOST }
end

function static_lease_max_check(n)
    local max = get_max_static_lease()
    local cur = form:count("dhcp", "host")
    
    if cur+n > max.max_rules then
        return false
    end
    
    return true
end

--- Insert a new dhcp static lease
function insert_static_lease(http_form)
    local form_data = json_m.decode(http_form.data)
    local params = form_data.params
    
    local new  = params.new or false
    
    if not new and type(new) ~= "table" then
        return false,error.ERR_DHCPS_INVALID_PARAMS
    end

    local mac = (type(new.mac)=="table") and new.mac or {new.mac}
    local ip = (type(new.ip)=="table") and new.ip or {new.ip}
    local interface = (type(new.interface)=="table") and new.interface or {new.interface}
    local enable = (type(new.enable)=="table") and new.enable or {new.enable}
    local notes = (type(new.note)=="table") and new.note or {new.note}

    local number_mac = table.getn(mac)
    local number_ip = table.getn(ip)
    local number_interface = table.getn(interface)
    local number_enable = table.getn(enable)
    if number_mac ~= number_ip or number_mac ~= number_interface or  number_mac ~= number_enable or number_mac == 0 then
        return false
    end
    if not static_lease_max_check(number_mac) then
        return false,error.ERR_DHCPS_MAX_LIMIT
    end

    local i=0
    local j=0
    local new_mac=""
    local ret 

    for i,new_mac in ipairs(mac) do
        new_mac = string.gsub(new_mac:upper(), "-", ":")
        local new_ip = ip[i]
        if not dtype.macaddr(new_mac) or not dtype.ipaddr(new_ip) then
            return false,error.ERR_DHCPS_MAC_IP_INVALID
        end
        local inter = zone_get_iface_bydev(interface[i])
        dbg(inter)
        if inter == "" then
            inter = interface[i]
        end
        if not ifs.update_if_reference(inter, 1) then
            return false, error.ERR_COM_ADD_REFERENCE_FAILED
        end

        local tmp = {}
        tmp.mac = new_mac
        tmp.ip = new_ip
        tmp.interface = inter
        tmp.enable = enable[i]
		tmp.note = notes[i] or ""
        ret = form:insert("dhcp", "host", tmp, {"interface","ip", "mac"})
        if not ret then
           return false,error.ERR_COM_TABLE_ITEM_UCI_ADD 
        end
    end



    -- duplication detection
--[[
    if new.enable == "on" then
        if Imb:arplist_check_dup(new) then
            return false, error.ERR_DHCPS_IMB_DUPLICATION
        end
    end
]]--

  
   
    if ret then ret.mac = string.gsub(ret.mac, ":", "-") end
    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
        return ret
    end
    return false
end

--- Remove a dhcp static lease selected by UI
function remove_static_lease(http_form)
		local form_data=json_m.decode(http_form.data)
		local params = form_data.params
		
		local key = params.key or {}
		local index = params.index or {}
        local extrakey = params.extraKey or {}
		--dbg("key:",key)
		--dbg("index:",index)
		key = utl.split(key, ',')
		index = utl.split(index, ',')
        extrakey = utl.split(extrakey, ',')
		--dbg("key:",key)
		--dbg.dumptable(key)
		--dbg("index:",index)
		--dbg.dumptable(index)
    if extrakey then
        for i, v in pairs(extrakey) do
            if not ifs.update_if_reference(v, 0) then
                return false, error.ERR_COM_DEL_REFERENCE_FAILED
            end
        end
    end

    local ret = form:delete("dhcp", "host", key, index)

    if ret then
        uci_r:commit("dhcp")
		userconfig.cfg_modify()
        return ret
    else
        return false, error.ERR_COM_TABLE_ITEM_UCI_DEL
    end

end

--- Remove all dhcp static lease host
function remove_all_static_lease()
    local secs = {}

    uci_r:foreach("dhcp", "host",
        function(section)
            secs[#secs + 1] = section[".name"]
            --uci_r:delete("dhcp", section[".name"])
        end
    )   

    for _, s in ipairs(secs) do
        uci_r:delete("dhcp", s)
    end

    uci_r:commit("dhcp")
	userconfig.cfg_modify()

    return true
end

-- Disable all invalid host static lease host
-- Details:
-- We need to go through all the static lease host entries to check whether the 
-- entry is still valid when our network ipaddr/netmask changes. If any entry
-- isn't in the range of new masked network, we disable it instead of removing 
-- it.
-- If any parameter(ipaddr/maskaddr) is not provided, we will get it from uci.
function disable_all_invalid_static_lease(ipaddr, maskaddr)
    ipaddr   = ipaddr   or uci_r:get("network", "lan", "ipaddr")
    maskaddr = maskaddr or uci_r:get("network", "lan", "netmask")
    --[[
    --dbg.printf("Para:Ipaddr  :" .. ipaddr)
    --dbg.printf("Para:maskaddr:" .. maskaddr)
    --]]--
    uci_r:foreach("dhcp", "host",
        function(section)
            local cfg_ip = section["ip"]
            local cfg_network = ipm.IPv4(cfg_ip, maskaddr):network()
            local new_network = ipm.IPv4(ipaddr, maskaddr):network()
            --[[
            --dbg.printf("CFG:IP:" .. cfg_ip)
            --dbg.printf("CFG:NETWORK:" .. cfg_network:string())
            --dbg.printf("NEW:NETWORK:" .. new_network:string())
            --]]--
            if new_network:string() ~= cfg_network:string() then
                uci_r:set("dhcp", section[".name"], "enable", "off")
            --[[
                --dbg.printf("Turn Off this entry.")
            else
                --dbg.printf("Keep Current config.")
            --]]--
            end
        end
    )   

    uci_r:commit("dhcp")
	userconfig.cfg_modify()
end

function dhcplease_check_dup(new)
    local settings = get_dhcp_settings()
    if settings.enable == "on" then
        local static_leases = load_static_leases()
        if not static_leases then
            return false
        end

        for _, e in ipairs(static_leases) do
            if e.enable == "on" then
                if new.ipaddr == e.ip or new.mac:gsub('-', ':'):upper() == e.mac:gsub('-', ':'):upper() then
                    return true
                end
            end
        end
    end
    return false
end


function get_lan_settings()
    local ret   = {}
	local lan_ipaddr = uci_r:get("network", "lan", "ipaddr")
	if not lan_ipaddr then
		return false, err.ERR_COM_TABLE_ITEM_UCI_GET
	end
    ret.ipaddr  = lan_ipaddr
	
	local lan_netmask = uci_r:get("network", "lan", "netmask")
	if not lan_netmask then
		return false, err.ERR_COM_TABLE_ITEM_UCI_GET
	end
    ret.netmask = lan_netmask

    local lan_macaddr  = uci_r:get("network", "lan","macaddr")
    if not lan_macaddr then
        return false, err.ERR_COM_TABLE_ITEM_UCI_GET
    end 
    ret.macaddr = string.gsub(lan_macaddr, ":", "-")
  
    return ret
end

function set_lan_settings(http_form)
    local form_data = json_m.decode(http_form.data)
    local params    = form_data.params
	if not params then
		return false
	end
	local dev       = "lan"

	local old_ipaddr = uci_r:get("network", dev, "ipaddr")
	if not old_ipaddr then
		return false, err.ERR_COM_TABLE_ITEM_UCI_GET
	end
	if params.ipaddr ~= old_ipaddr then
		local uci_res = uci_r:set("network", dev, "ipaddr", params.ipaddr)
		if not uci_res then
			return false, err.ERR_COM_TABLE_ITEM_UCI_SET
		end
	end
	
	local old_netmask = uci_r:get("network", dev, "netmask")
	if not old_netmask then
		return false, err.ERR_COM_TABLE_ITEM_UCI_GET
	end
	if params.netmask ~= old_netmask then
		local uci_res = uci_r:set("network", dev, "netmask", params.netmask)
		if not uci_res then
			return false, err.ERR_COM_TABLE_ITEM_UCI_SET
		end
	end
	
	local uci_res = uci_r:commit("network")
	if not uci_res then
		return false, err.ERR_COM_UCI_COMMIT
	end
    -- sync DHCP60/138 for AC
    local ap_state = uci_r:get("ac_apmngr", "settings", "apmngr_enable")
    if ap_state and ap_state == "on" then
        local options = uci_r:get("dhcp", "lan", "dhcp_option")
        option60_index = 0
        option138_index = 0
        for pos, op in ipairs(options) do
            local op_code = op:match("(%d+),")
            if op_code == "60" then             
                option60_index = pos
            elseif op_code == "138" then
                option138_index = pos
            end                
        end

        if option60_index ~= 0 then
            options[option60_index] = "60,TP-LINK"
        else
            options[#options+1] = "60,TP-LINK"                
        end

        if option138_index ~= 0 then
            options[option138_index] = "138,"..params.ipaddr   
        else
            options[#options+1] = "138,"..params.ipaddr    
        end

        uci_r:delete("dhcp","lan", "dhcp_option")
        uci_r:set("dhcp", "lan", "dhcp_option", options)

        local uci_res = uci_r:commit("dhcp")
        if not uci_res then
            return false, err.ERR_COM_UCI_COMMIT
        end
    elseif ap_state and ap_state == "off" then
        local options = uci_r:get("dhcp", "lan", "dhcp_option")
        local need_sync = false

        local old_138_value = "138,"..old_ipaddr
        for _, op in ipairs(options) do           
            if op == old_138_value then
                need_sync = true
            end
        end

        if need_sync then
            option60_index = 0
            option138_index = 0
            for pos, op in ipairs(options) do
                local op_code = op:match("(%d+),")
                if op_code == "60" then             
                    option60_index = pos
                elseif op_code == "138" then             
                    option138_index = pos
                end                
            end

            if option60_index ~= 0 then
                options[option60_index] = "60,TP-LINK"
            else
                options[#options+1] = "60,TP-LINK"                
            end

            if option138_index ~= 0 then
                options[option138_index] = "138,"..params.ipaddr   
            else
                options[#options+1] = "138,"..params.ipaddr    
            end

            uci_r:delete("dhcp","lan", "dhcp_option")
            uci_r:set("dhcp", "lan", "dhcp_option", options)

            local uci_res = uci_r:commit("dhcp")
            if not uci_res then
                return false, err.ERR_COM_UCI_COMMIT
            end
        end

    end

    -- sync ipstat setting
    local ipstat = {}
    local ipstatreloadcmd = "/etc/init.d/ipstat restart"
    ipstat.ip = uci_r:get("ipstat", "setting", "ip")
    ipstat.mask = uci_r:get("ipstat", "setting", "mask")
    local ipstat_ipv4_network = luci.ip.IPv4(ipstat.ip, ipstat.mask):network():string()
    local old_lan_ipv4_network = luci.ip.IPv4(old_ipaddr, old_netmask):network():string()
    -- if ipstat is user defined: different from lan setting
    if (ipstat_ipv4_network == old_lan_ipv4_network) and (ipstat.mask == old_netmask) then
        local lan_ipv4_network = luci.ip.IPv4(params.ipaddr, params.netmask):network():string()
        uci_r:set("ipstat", "setting", "ip", lan_ipv4_network)
        uci_r:set("ipstat", "setting", "mask", params.netmask)
        if not uci_r:commit("ipstat") then
            return false, err.ERR_COM_UCI_COMMIT
        end
        sys.fork_exec(ipstatreloadcmd)
    end

	--set_default_dhcp_options()
	recalc_pool()
	userconfig.cfg_modify()
	sys.fork_exec(nwreloadcmd)
	
	return get_lan_settings()
end


-- General controller routines

local dhcps_forms = {
    lan ={
         ["get"] = {cb = get_lan_settings},
         ["set"] = {cb = set_lan_settings}
	},
    setting = {
        ["get"] = {cb = get_dhcp_settings},
        ["set"] = {cb = update_dhcp_server2, cmd = RELOAD}
    },
	server = {
        ["get"] = {cb = load_dhcp_servers, others = get_max_servers},
        ["add"] = {cb = insert_dhcp_server, others = get_max_servers, cmd = RELOAD},
        ["set"] = {cb = update_dhcp_server, others = get_max_servers, cmd = RELOAD},
        ["delete"] = {cb = remove_dhcp_server, others = get_max_servers, cmd = RELOAD},
        ["clear"]  = {cb = remove_dhcp_server}--cmd=RELOAD
    }, 
    client = {
        ["get"] = {cb = load_active_leases},
		["flush"] = {cb = leases_flush}
    },
    reservation = {
        ["get"] = {cb = load_static_leases, others = get_max_static_lease},
        ["add"] = {cb = insert_static_lease, others = get_max_static_lease, cmd = RELOAD},
        ["set"] = {cb = update_static_lease, others = get_max_static_lease, cmd = RELOAD},
        ["delete"] = {cb = remove_static_lease, others = get_max_static_lease, cmd = RELOAD},
        ["clear"]  = {cb = remove_all_static_lease}--cmd=RELOAD
    }
}

function index()
    entry({"admin", "dhcps"}, call("dhcp_index")).leaf = true
end

local ctl = require "luci.model.controller"

function dhcp_index()
    ctl._index(dhcp_dispatch)
end

function dhcp_dispatch(http_form)
    local function hook(success, action)
        if success and action.cmd and action.cmd ~= "" then
            sys.fork_exec("%s %s" % {DHCPS_SHELL, action.cmd})
        end
        return true
    end
    return ctl.dispatch(dhcps_forms, http_form, {post_hook = hook})
end
