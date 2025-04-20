# frozen_string_literal: true

require 'json'

class TypedStruct
  class << self
    def define(name, typedef, tags = [])
      unless Typed::Internal.supported_type?(typedef)
        raise ArgumentError,
              "typedef #{typedef.inspect} is not supported"
      end

      __attributes[name] = typedef

      attr_reader name

      define_method "#{name}=" do |v|
        assign! name, v
      end
    end

    # TypedSerialize#unmarshal から呼び出される
    def unmarshal(hash)
      hash.each_key do |key|
        typedef = __attributes[key]
        hash[key] = typedef.unmarshal hash[key] if Typed::Internal.typed_struct_typedef?(typedef) && !hash[key].nil?
      end
      new(hash)
    end

    def __attributes
      @__attributes ||= {}
    end
  end

  # インスタンス化時に初期値を指定する場合、{ [key] => value } 形式で渡す
  def initialize(init = {})
    self.class.__attributes.each do |name, typedef|
      zero = Typed::Internal.zero_value typedef
      value = init.fetch name, zero
      assign! name, value
    end
  end

  def []=(key, value)
    assign! key.to_sym, value
  end

  def [](key)
    instance_variable_get "@#{key}"
  end

  # TypedSerialize#marshal から呼び出される
  def marshal
    hash = {}
    self.class.__attributes.each_key do |name|
      v = instance_variable_get "@#{name}"

      v = v.marshal if v.is_a?(TypedStruct)
      v = v.map(&:marshal) if Typed::Internal.array_typedef?(self.class.__attributes[name])

      hash[name] = v
    end
    hash
  end

  private

  def assign!(to, value)
    ok = safe_assign to, value
    return if ok

    raise TypeError, "cannot assign #{value.inspect} to #{self.class}.#{to}"
  end

  def safe_assign(to, value)
    typedef = self.class.__attributes[to]
    return false unless Typed::Internal.type_correct?(typedef, value)

    instance_variable_set "@#{to}", value
    true
  end
end

module Typed
  module Internal
    def self.zero_value(typedef)
      if primitive_typedef? typedef
        return {
          int: 0,
          string: '',
          any: nil
        }[typedef]
      end

      return nil if typed_struct_typedef? typedef

      return [] if array_typedef? typedef

      raise TypeError, "typedef #{typedef.inspect} is not supported"
    end

    def self.primitive_typedef?(typedef)
      %i[int string any].include? typedef
    end

    def self.typed_struct_typedef?(typedef)
      return false unless typedef.respond_to? :superclass
      return false unless typedef.superclass == TypedStruct

      true
    end

    def self.array_typedef?(typedef)
      return false unless typedef.is_a? Array
      return false unless typedef.length == 1
      return false unless supported_type?(typedef[0])

      true
    end

    def self.supported_type?(typedef)
      return true if primitive_typedef?(typedef)
      return true if array_typedef?(typedef)
      return true if typed_struct_typedef?(typedef)

      false
    end

    def self.type_correct?(typedef, v)
      if primitive_typedef?(typedef)
        case typedef
        when :int
          return v.is_a? Integer
        when :string
          return v.is_a? String
        when :any
          return true
        end
      end

      return v.nil? || v.is_a?(typedef) if typed_struct_typedef? typedef

      return v.all? { |el| type_correct?(typedef[0], el) } if array_typedef? typedef

      raise ArgumentError, "typedef #{typedef.inspect} is not supported"
    end

    RubyJSON = JSON
  end
end

module TypedSerialize
  module MarshalArray
    refine Array do
      def marshal
        map(&:marshal)
      end
    end
  end

  module JSON
    using TypedSerialize::MarshalArray

    # JSON 文字列に変換する。オブジェクトが marshal() -> String メソッドを持つ場合、そのメソッドの返り値 (Hash) を利用する。
    def marshal(v)
      h = v.marshal
      Typed::Internal::RubyJSON.generate h
    end

    # JSON 文字列から typedef で指定した型の TypedStruct に変換する。オブジェクトが unmarshal(Hash) -> T メソッドを持つ場合、そのメソッドを利用する。
    def unmarshal(data, typedef)
      h = Typed::Internal::RubyJSON.parse data, symbolize_names: true
      typedef.unmarshal h
    end

    module_function :marshal, :unmarshal
  end
end
