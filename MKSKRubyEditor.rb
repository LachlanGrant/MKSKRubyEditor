require 'sketchup.rb'
require 'extensions.rb'

mkskrubyeditor = SketchupExtension.new "MKSKRubyEditor", "MKSKRubyEditor/MKSKRubyEditor.rb"
mkskrubyeditor.copyright= 'Copyright 2013-2017 Lachlan Grant.'
mkskrubyeditor.creator= 'Lachlan Grant'
mkskrubyeditor.version = '1.0'
mkskrubyeditor.description = "TODO"
Sketchup.register_extension mkskrubyeditor, true
