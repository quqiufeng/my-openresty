describe("Admin",function()
  test("index",function()
    local c={json=function()end,admin_model={list=function()return{}end}}
    c.index=function()end c.index()
  end)
end)
