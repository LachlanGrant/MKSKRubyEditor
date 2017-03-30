require 'sketchup'

module MKSK
  class RubyEditor < UI::WebDialog

      def initialize
        @rceVersion = "1.0"
        @as_su_os = (Object::RUBY_PLATFORM =~ /mswin/i) ? 'windows' :
          ((Object::RUBY_PLATFORM =~ /darwin/i) ? 'mac' : 'other')
        @baseDir = File.dirname(__FILE__)
        @user_dir = (ENV['USERPROFILE'] != nil) ? ENV['USERPROFILE'] :
          ((ENV['HOME'] != nil) ? ENV['HOME'] : @baseDir )
        @initCode = Sketchup.read_default "as_RubyCodeEditor", "init_code", 'mod = Sketchup.active_model # Open model\nent = mod.entities # All entities in model\nsel = mod.selection # Current selection'
        @last_file = Sketchup.read_default "as_RubyCodeEditor", "last_file"
        if @last_file != nil
          @snip_dir = @last_file
        else
          @snip_dir = @user_dir
        end
        @snip_dir = @snip_dir.split("/").join("\\") + "\\"
        if @as_su_os != 'windows'
          @snip_dir = @snip_dir.split("\\").join("/") + "/"
        end

        super "Ruby Code Editor", false, "RubyCodeEditor", 750, 600, 100, 100, true
        ui_loc = File.join(@baseDir , "ui.html")
        # Fix directory name on Win
        ui_loc.gsub!('//', "/")
        # Set HTML UI file for WebDialog
        set_file(ui_loc)
        navigation_buttons_enabled = false
        min_width = 750
        min_height = 600

        add_action_callback("exec") do |dlg, params|
          dlg.execute_script("addResults('Running the code...')")
          v = dlg.get_element_value('console').strip
          # puts v
          r = nil
          begin
            if params == 'true'
              Sketchup.active_model.start_operation "RubyEditor"
            end
            begin
              r = eval v
            rescue => e
              r = e
              raise
            end
          rescue
            Sketchup.active_model.abort_operation
            r = 'Run aborted. Error: ' + e
          else # only do if NO errors
            if params == 'true'
              Sketchup.active_model.commit_operation
            end
          ensure
            r!=nil ? r = r.to_s : r='Nil result (no result returned or run failed)'
            p r
            r.gsub!(/ /, "&nbsp;")
            r.gsub!(/\n/, "<br>")
            r.gsub!(/'/, "&rsquo;")
            r.gsub!(/`/, "&lsquo;")
            r.gsub!(/</, "&lt;")
            dlg.execute_script("addResults('Done. Ruby says: <span class=\\'hl\\'>#{r}</span>')")
          end
        end

        add_action_callback("new") do |dlg, params|
          # Use only single quotes here!
          script = 'editor.setValue(\''+@initCode+'\')'
          dlg.execute_script(script)
          dlg.execute_script("editor.scrollTo(0,0)")
          dlg.execute_script("addResults('Cleared the editor')")
          dlg.execute_script("$('#save_name').text('untitled.rb')")
          dlg.execute_script("$('#save_filename').val('untitled.rb')")
          dlg.execute_script("editor.markClean()")
        end

        add_action_callback("load") do |dlg, params|
          p @snip_dir
          file = UI.openpanel("Open File", @snip_dir, "*.*")
          return unless file
          @snip_dir = File.dirname(file)
          name = File.basename(file)
          extension = File.extname(file)
          @file = file
          dlg.execute_script("$('#save_name').text('#{name}')")
          dlg.execute_script("$('#save_filename').val('#{name}')")
          if params != "true"
            dlg.execute_script(%/document.getElementById('console').value=""/)
          end
          f = File.new(file,"r")
          text = f.readlines.join

          text.gsub!('\\', "<84JSed>")
          text.gsub!('\'', "<25SKxw>")
          text.gsub!(/\n/, "\\n")
          text.gsub!(/\r/, "\\r")
          text.gsub!(/'\'/, '\\')

          dlg.execute_script("tmp = '#{text}'")
          dlg.execute_script("tmp = tmp.replace(/<84JSed>/g,'\\\\')")
          dlg.execute_script("tmp = tmp.replace(/<25SKxw>/g,'\\'')")
          script = 'editor.setValue(tmp)'
          dlg.execute_script(script)

          dlg.execute_script("editor.scrollTo(0,0)")
          dlg.execute_script("addResults('File loaded: #{name}')")
          dlg.execute_script("editor.markClean()")

          Sketchup.write_default "as_RubyCodeEditor", "last_file", file
        end

        add_action_callback("save") do |dlg, params|
          filename = dlg.get_element_value("save_filename")
          file = UI.savepanel("Save File", @snip_dir, filename)
          return if file.nil?

          @snip_dir = File.dirname(file)
          name = File.basename(file)
          extension = File.extname(file)

          if extension == ""
            name = name+".rb"
            file = file+".rb"
          end
          str=dlg.get_element_value("console")
          str.gsub!(/\r\n/, "\n")

          if File.exist?(file) and params == 'true'
            f = File.new(file,"r")
            oldfile = f.readlines
            File.open(file+".bak", "w") { |f| f.puts oldfile }
          end
          File.open(file, "w") { |f| f.puts str }
          dlg.execute_script("$('#save_name').text('#{name}')")
          dlg.execute_script("$('#save_filename').val('#{name}')")
          dlg.execute_script("editor.markClean()")
          dlg.execute_script("addResults('File saved: #{name}')")

          Sketchup.write_default "as_RubyCodeEditor", "last_file", file
        end

        set_on_close do
          execute_script("addResults('Closing editor...')")
          result = UI.messagebox "Save this file before quitting?", MB_YESNO
          if result == 6 then
            filename = get_element_value("save_filename")
            file = UI.savepanel("Save File", @snip_dir, filename)
            return if file.nil?
            # Set file directory as current
            @snip_dir = File.dirname(file)
            name = File.basename(file)
            extension = File.extname(file)

            if extension == ""
              name = name+".rb"
              file = file+".rb"
            end

            execute_script("editor.save()")
            str=get_element_value("console")
            str.gsub!(/\r\n/, "\n")

            if File.exist?(file)
              f = File.new(file,"r")
              oldfile = f.readlines
              File.open(file+".bak", "w") { |f| f.puts oldfile }
            end
            File.open(file, "w") { |f| f.puts str }

            Sketchup.write_default "as_RubyCodeEditor", "last_file", file
          end
        end

        add_action_callback("quit") { |dlg, params|
          dlg.close
        }

        add_action_callback("undo") do |dlg, params|
          Sketchup.undo
          dlg.execute_script("addResults('Last step undone')")
        end # callback

        add_action_callback("sel_explore") do |dlg, params|
          sel = Sketchup.active_model.selection
          mes = ""
          mes += "#{sel.length} "
          mes += sel.length == 1 ? "entity" : "entities"
          mes += " selected\n\n"
          sel.each_with_index { |item,i|
            mes += "Entity: #{sel[i].to_s}\n"
            mes += "Type: #{sel[i].typename}\n"
            mes += "ID: #{sel[i].entityID}\n"
            if sel[i].typename == "ComponentInstance"
              mes += "Definition name: #{sel[i].definition.name}\n"
            end
            mes += "Parent: #{sel[i].parent}\n"
            mes += "Layer: #{sel[i].layer.name}\n"
            mes += "Center location: #{sel[i].bounds.center}\n"
            mes += "\n"
          }
          UI.messagebox mes , MB_MULTILINE, "Explore Current Selection"
        end # callback


        add_action_callback("att_explore") do |dlg, params|
          sel = Sketchup.active_model.selection
          mes = ""
          mes += "#{sel.length} "
          mes += sel.length == 1 ? "entity" : "entities"
          mes += " selected\n\n"
          sel.each_with_index { |item,i|
            mes += "Entity: #{sel[i].to_s}\n"
            if sel[i].attribute_dictionaries
              mes += "Attribute dictionaries:\n"
              names = ""
              sel[i].attribute_dictionaries.each {|dic|
                mes += "  Dictionary name: #{dic.name}\n"
                dic.each { | key, value |
                  mes += "    " + key.to_s + '=' + value.to_s + "\n"
                }
              }
            else
              mes += "No attributes defined\n"
            end
            mes += "\n"
          }
          UI.messagebox mes , MB_MULTILINE, "Explore Current Selection's Attributes"
        end


        add_action_callback("show_console") do |dlg, params|
          Sketchup.send_action "showRubyPanel:"
        end

        show do
          script = 'editor.setValue(\''+@initCode+'\')'
          execute_script(script)
          execute_script("rceVersion = #{@rceVersion}")
          execute_script("editor.markClean()")
        end


     end


  end


end

file = File.basename(__FILE__)

unless file_loaded?(file)
  UI.menu("Window").add_item("Ruby Code Editor") { editordlg = MKSK::RubyEditor.new }

  pluginMenu = UI.menu('Plugins').add_submenu('SKGroup')
  pluginMenu.add_item('Ruby Editor') {MKSK::RubyEditor.new}

   as_rce_tb = UI::Toolbar.new "SKGroup"
   as_rce_cmd = UI::Command.new("Ruby Editor") { editordlg = MKSK::RubyEditor.new }
   # One instance only version:
   # as_rce_cmd = UI::Command.new("Ruby Code Editor") { editordlg = AS_RubyEditor::RubyEditor.new unless editordlg }
#   as_rce_cmd.small_icon = "img/rce_1_16.png"
#   as_rce_cmd.large_icon = "img/rce_1_24.png"
   as_rce_cmd.tooltip = "Ruby Editor"
   as_rce_cmd.status_bar_text = "Edit and run Ruby scripts in a nice-looking dialog"
   as_rce_cmd.menu_text = "Ruby Editor"
   as_rce_tb = as_rce_tb.add_item as_rce_cmd
   as_rce_tb.show

  file_loaded file
end