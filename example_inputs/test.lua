function get_mode(s)local t=0
    local n=nil
    n=s[e.optName.hwmode]if e.optValue.hwMode.mode11b==n then
    t=a.m_11b
    elseif e.optValue.hwMode.mode11g==n then
    t=a.m_11g
    elseif e.optValue.hwMode.mode11bg==n then
    t=a.m_11bg
    elseif e.optValue.hwMode.mode11n==n then
    t=a.m_11n
    elseif e.optValue.hwMode.mode11bgn==n then
    t=a.m_11bgn
    elseif e.optValue.hwMode.mode11an==n then
    t=a.m_11an
    elseif e.optValue.hwMode.mode11ac==n then
    t=a.m_11ac
    else
    end
    return t
    end