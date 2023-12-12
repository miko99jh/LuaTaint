x = io.read()
while x > 1 do
    y = 2;
    if y > 3 then
        x = x-y;
    end
    z = x-4;
    if z > 0 then
        x = x / 2;
    end
    z = z - 1;
end
print(x)