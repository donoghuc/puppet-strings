require 'puppet-strings'
require 'puppet-strings/json'
require 'puppet-strings/yard'

module PuppetStrings::Markdown
  # This class makes elements in a YARD::Registry hash easily accessible for templates.
  #
  # Here's an example hash:
  #{:name=>:klass,
  # :file=>"(stdin)",
  # :line=>16,
  # :inherits=>"foo::bar",
  # :docstring=>
  #  {:text=>"An overview for a simple class.",
  #   :tags=>
  #    [{:tag_name=>"summary", :text=>"A simple class."},
  #     {:tag_name=>"since", :text=>"1.0.0"},
  #     {:tag_name=>"see", :name=>"www.puppet.com"},
  #     {:tag_name=>"example",
  #      :text=>
  #       "class { 'klass':\n" +
  #       "  param1 => 1,\n" +
  #       "  param3 => 'foo',\n" +
  #       "}",
  #      :name=>"This is an example"},
  #     {:tag_name=>"author", :text=>"eputnam"},
  #     {:tag_name=>"option", :name=>"opts"},
  #     {:tag_name=>"raise", :text=>"SomeError"},
  #     {:tag_name=>"param",
  #      :text=>"First param.",
  #      :types=>["Integer"],
  #      :name=>"param1"},
  #     {:tag_name=>"param",
  #      :text=>"Second param.",
  #      :types=>["Any"],
  #      :name=>"param2"},
  #     {:tag_name=>"param",
  #      :text=>"Third param.",
  #      :types=>["String"],
  #      :name=>"param3"}]},
  # :defaults=>{"param1"=>"1", "param2"=>"undef", "param3"=>"'hi'"},
  # :source=>
  #  "class klass (\n" +
  #  "  Integer $param1 = 1,\n" +
  #  "  $param2 = undef,\n" +
  #  "  String $param3 = 'hi'\n" +
  #  ") inherits foo::bar {\n" +
  #  "}"}
  class Base
    def initialize(registry, component_type)
      @type = component_type
      @registry = registry
      @tags = registry[:docstring][:tags] || []
    end

    # generate 1:1 tag methods
    # e.g. {:tag_name=>"author", :text=>"eputnam"}
    { :return_val => 'return',
      :since => 'since',
      :summary => 'summary',
      :note => 'note',
      :todo => 'todo' }.each do |method_name, tag_name|
      # @return [String] unless the tag is nil or the string.empty?
      define_method method_name do
        @tags.find { |tag| tag[:tag_name] == tag_name && !tag[:text].empty? }[:text] if @tags.any? { |tag| tag[:tag_name] == tag_name && !tag[:text].empty? }
      end
    end

    # @return [String] top-level name
    def name
      @registry[:name].to_s unless @registry[:name].nil?
    end

    # @return [String] 'Overview' text (untagged text)
    def text
      @registry[:docstring][:text] unless @registry[:docstring][:text].empty?
    end

    # @return [String] data type of return value
    def return_type
      @tags.find { |tag| tag[:tag_name] == 'return' }[:types][0] if @tags.any? { |tag| tag[:tag_name] == 'return' }
    end

    # @return [String] text from @since tag
    def since
      @tags.find { |tag| tag[:tag_name] == 'since' }[:text] if @tags.any? { |tag| tag[:tag_name] == 'since' }
    end

    # @return [Array] @see tag hashes
    def see
      select_tags('see')
    end

    # @return [Array] parameter tag hashes
    def params
      select_tags('param')
    end

    # @return [Array] example tag hashes
    def examples
      select_tags('example')
    end

    # @return [Array] raise tag hashes
    def raises
      select_tags('raise')
    end

    # @return [Array] option tag hashes
    def options
      select_tags('option')
    end

    # @param parameter_name
    #   parameter name to match to option tags
    # @return [Array] option tag hashes that have a parent parameter_name
    def options_for_param(parameter_name)
      opts_for_p = options.select { |o| o[:parent] == parameter_name } unless options.nil?
      opts_for_p unless opts_for_p.nil? || opts_for_p.length.zero?
    end

    # @return [Hash] any defaults found for the component
    def defaults
      @registry[:defaults] unless @registry[:defaults].nil?
    end

    # @return [Hash] information needed for the table of contents
    def toc_info
      {
        name: name.to_s,
        link: link,
        desc: summary || @registry[:docstring][:text][0..140].gsub("\n",' '),
        private: private?
      }
    end

    # @return [String] makes the component name suitable for a GitHub markdown link
    def link
      name.delete('::').strip.gsub(' ','-').downcase
    end

    # Some return, default, or valid values need to be in backticks. Instead of fu in the handler or code_object, this just does the change on the front.
    # @param value
    #  any string
    # @return [String] value or value in backticks if it is in a list
    def value_string(value)
      to_symbol = %w[undef true false]
      if to_symbol.include? value
        return "`#{value}`"
      else
        return value
      end
    end

    def private?
      @tags.any? { |tag| tag[:tag_name] == 'api' && tag[:text] == 'private' }
    end

    # @return [String] full markdown rendering of a component
    def render(template)
      file = File.join(File.dirname(__FILE__),"templates/#{template}")
      ERB.new(File.read(file), nil, '-').result(binding)
    end

    private

    def select_tags(name)
      tags = @tags.select { |tag| tag[:tag_name] == name }
      tags.empty? ? nil : tags
    end
  end
end
