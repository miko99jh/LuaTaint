module = {}
module.constant = "This is a constant"
function module.func1()
    io.write("This is a public function!\n")
end
local function func2()
    print("This is a private function!")
end
function module.func3()
    func2()
end

require("module")
print(module.constant)
module.func3()