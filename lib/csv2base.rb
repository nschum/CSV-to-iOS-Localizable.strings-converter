class Csv2Base
    attr_accessor :default_path, :output_file
    attr_accessor :langs
    attr_accessor :csv_filename
    attr_accessor :default_lang
    attr_accessor :excluded_states, :state_column, :keys_column

    def initialize(filename, langs, args = {})
        args.merge!({
            :excluded_states => [],
            :state_column => nil,
            :keys_column => 0
        })

        @langs = langs
        if !@langs.is_a?(Hash) || @langs.size == 0
            raise "wrong format or/and langs parameter" + @langs.inspect
        end

        @output_file = (langs.size == 1) ? args[:output_file] : nil
        @default_path = args[:default_path].to_s
        @csv_filename = filename
        @excluded_states = args[:excluded_states]
        @state_column = args[:state_column]
        @keys_column = args[:keys_column]
        @default_lang = args[:default_lang]
    end

    def create_file_from_path(file_path)
        path = File.dirname(file_path)
        FileUtils.mkdir_p path
        return File.new(file_path,"w")
    end

    def file_path_for_locale(locale)
        require 'pathname' 
        Pathname.new(self.default_path) + "#{locale}" + "lang.txt"
    end

    def process_header(excludedCols, files, row, index)
        files[index] = []
        lang_index = row[index]
        
        # create output files here
        if @output_file
            # one single file
            files[index] << self.create_file_from_path(@output_file)
        else
            # create one file for each langs
            if self.langs[lang_index].is_a?(Array)

                self.langs[lang_index].each do |locale|
                    filename = self.file_path_for_locale(locale)
                    files[index] << self.create_file_from_path(filename)
                end
            elsif self.langs[lang_index].is_a?(String)
                locale = self.langs[lang_index]
                filename = self.file_path_for_locale(locale)
                files[index] << self.create_file_from_path(filename)
            else
                raise "wrong format or/and langs parameter" 
            end

        end
    end

    def process_footer(file)

    end

    def process_value(row_value, default_value)
        value = row_value.nil? ? default_value : row_value
        value = "" if value.nil?
        value.gsub!(/\\*\"/, "\\\"") #escape double quotes
        value.gsub!(/\s*(\n|\\\s*n)\s*/, "\\n") #replace new lines with \n + strip
        value.gsub!(/%\s+([a-zA-Z@])([^a-zA-Z@]|$)/, "%\\1\\2") #repair string formats ("% d points" etc)
        value.gsub!(/([^0-9\s\(\{\[^])%/, "\\1 %")
        value.strip!
        return value
    end

    def get_row_format(row_key, row_value)
        return row_key + " = \"" + row_value + "\""
    end

    # Convert csv file to multiple Localizable.strings files for each column
    def convert(name = self.csv_filename)
        files        = {}
        rowIndex     = 0
        excludedCols = []
        defaultCol   = 0
        nb_translations = 0
        
        CSVParserClass.foreach(name, :quote_char => '"', :col_sep =>',', :row_sep => :auto) do |row|

            if rowIndex == 0
                #check there's at least two columns
                return unless row.count > 1
            else
                #skip empty lines (or sections)
                next if row == nil or row[self.keys_column].nil?
            end

            row.size.times do |i|
                next if excludedCols.include? i

                #header
                if rowIndex == 0
                    # ignore all headers not listed in langs to create files
                    (excludedCols << i and next) unless self.langs.has_key?(row[i])
                    self.process_header(excludedCols, files, row, i)
                    # define defaultCol
                    defaultCol = i if self.default_lang == row[i]

                elsif !self.state_column || (row[self.state_column].nil? or row[self.state_column] == '' or !self.excluded_states.include? row[self.state_column])
                    # TODO: add option to strip the constant or referenced language
                    key = row[self.keys_column].strip 
                    value = self.process_value(row[i], row[defaultCol])
                    # files for a given language, i.e could group english US with english UK.
                    localized_files = files[i]
                    if localized_files
                        localized_files.each do |file|
                            nb_translations += 1
                            file.write get_row_format(key, value)
                        end         
                    end
                end
            end
            rowIndex += 1
        end
        info = "Created #{files.size} files. Content: #{nb_translations} translations\n"
        info += "List of created files:\n"

        # closing I/O
        files.each do |key,locale_files|
            locale_files.each do |file|
                info += "#{file.path.to_s}\n"
                self.process_footer(file)
                file.close
            end
        end
        info
    end # end of method
end
