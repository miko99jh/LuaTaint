y = 1
for x = 0,5,1 do
    g = 10
    if x > y then
        while y < 5 do
            print( x)
            x = x + 1
        end
        print(y + x)
    else
        print(x*2)
        h = g * 2
    end
end
print(x)
