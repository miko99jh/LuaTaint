
module("luci.controller.admin.system", package.seeall)

local ctl = require "luci.model.controller"
local log = require "luci.model.log"
local MODULE_WEB = 88
local LOGOUT_SUCCESS = 14202

function logout()
    local sess = require("luci.dispatcher").context.authsession
    if sess then
        local sauth = require "luci.sauth"
        sauth.kill(sess)
    end
    local sys = require "luci.sys"
    local ipaddr = sys.getenv("REMOTE_ADDR")
    log.logger_reg(MODULE_WEB, LOGOUT_SUCCESS, ipaddr)
    return true
end

function reboot()
    local sys = require "luci.sys"
    sys.fork_exec("sleep 1; reboot")
    return true
end

-- General controller routines

local dispatch_tbl = {
    logout = {
        [".super"] = {cb = logout}
    },
    reboot = {
        [".super"] = {cb = reboot}
    }
}

function dispatch(http_form)
    return ctl.dispatch(dispatch_tbl, http_form)
end

function _index()
    return ctl._index(dispatch)
end

function index()
    entry({"admin", "system"}, call("_index")).leaf = true
end
