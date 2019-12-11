hexchat.register(
  "Test",
  "0",
  "Test addon"
)

function main ()
    local lgi = require("lgi")
    local lgitbl = getmetatable(lgi).__index
    -- I don't know how to confirm if the Gtk table is present in the returned lgi table

    --[==[
    for i=1,select('#', lgitbl) do
        print(([[
%s: %s
]]):format( i, tostring(select(i, lgitbl)) )
        )
    end
    for k,v in pairs(lgitbl) do
        print(([[
k: %s
v: %s
]]):format( tostring(k) , tostring(v) ))
    end
    --]==]

    --[[
    local window = lgi.Gtk.Window {
        title = "Test"
    }
    window:show()
    --]]

    -- First idea is to make a whole window that can be interacted with to configure the plugin
    local interface_xml = [[
<interface>
  <object class="GtkDialog" id="dialog1">
    <child internal-child="vbox">
      <object class="GtkBox" id="vbox1">
        <property name="border-width">10</property>
        <child internal-child="action_area">
          <object class="GtkButtonBox" id="hbuttonbox1">
            <property name="border-width">20</property>
            <child>
              <object class="GtkButton" id="ok_button">
                <property name="label">gtk-ok</property>
                <property name="use-stock">TRUE</property>
                <signal name="clicked" handler="ok_button_clicked"/>
              </object>
            </child>
          </object>
        </child>
      </object>
    </child>
  </object>
</interface>
]]
    local interface = lgi.Gtk.Builder():add_from_string(interface_xml)

    -- Second idea is to, if possible, add menu items to hexchat's Preferences menu
    
end

main()