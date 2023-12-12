local bwc = io.popen("luci-bwc -r %q 2>/dev/null" % iface)
if bwc then
    luci.http.write("[")

    while true do
        local ln = bwc:read("*l")
        if not ln then break end
        luci.http.write(ln)
    end

    luci.http.write("]")
    bwc:close()
end