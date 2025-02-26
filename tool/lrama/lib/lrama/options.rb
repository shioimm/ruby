# frozen_string_literal: true

module Lrama
  # Command line options.
  class Options
    attr_accessor :skeleton, :header, :header_file,
                  :report_file, :outfile,
                  :error_recovery, :grammar_file,
                  :trace_opts, :report_opts,
                  :diagnostic, :y, :debug, :define

    def initialize
      @skeleton = "bison/yacc.c"
      @define = {}
      @header = false
      @header_file = nil
      @report_file = nil
      @outfile = "y.tab.c"
      @error_recovery = false
      @grammar_file = nil
      @trace_opts = nil
      @report_opts = nil
      @diagnostic = false
      @y = STDIN
      @debug = false
    end
  end
end
