# frozen_string_literal: true

require 'json'

class TypedStruct
  class << self
    def define(name, type, tags = [])
      raise ArgumentError, "type #{type.inspect} is not supported type" unless Typed::Internal.supported_type?(type)

      __attributes[name] = type

      attr_reader name

      define_method "#{name}=" do |v|
        assign! name, v
      end
    end

    def __attributes
      @__attributes ||= {}
    end
  end

  # インスタンス化時に初期値を指定する場合、{ [key] => value } 形式で渡す
  def initialize(init = {})
    self.class.__attributes.each do |name, type|
      zero = Typed::Internal.zero_value type
      value = init.fetch name, zero
      assign! name, value
    end
  end

  # JSON に変換
  def to_json(*args)
    # FIXME: TypedSerde に移行
    hash = {}
    self.class.__attributes.each_key do |name|
      hash[name] = instance_variable_get "@#{name}"
    end
    hash.to_json(*args)
  end

  def []=(key, value)
    assign! key.to_sym, value
  end

  def [](key)
    instance_variable_get "@#{key}"
  end

  private

  def assign!(to, value)
    ok = safe_assign to, value
    return if ok

    raise TypeError, "cannot assign #{value.inspect} to #{self.class}.#{to}"
  end

  def safe_assign(to, value)
    t = self.class.__attributes[to]
    return false unless Typed::Internal.type_correct?(t, value)

    instance_variable_set "@#{to}", value
    true
  end
end

module Typed
  module Internal
    def self.zero_value(t)
      if primitive_typedef? t
        return {
          int: 0,
          string: '',
          any: nil
        }[t]
      end

      return nil if typed_struct_typedef? t

      return [] if array_typedef? t

      raise TypeError, "type #{t.inspect} is not supported type"
    end

    def self.primitive_typedef?(t)
      %i[int string any].include? t
    end

    def self.typed_struct_typedef?(t)
      return false unless t.respond_to? :superclass
      return false unless t.superclass == TypedStruct

      true
    end

    def self.array_typedef?(t)
      return false unless t.is_a? Array
      return false unless t.length == 1
      return false unless supported_type?(t[0])

      true
    end

    def self.supported_type?(t)
      return true if primitive_typedef?(t)
      return true if array_typedef?(t)
      return true if typed_struct_typedef?(t)

      false
    end

    def self.type_correct?(t, v)
      if primitive_typedef?(t)
        case t
        when :int
          return v.is_a? Integer
        when :string
          return v.is_a? String
        when :any
          return true
        end
      end

      return v.nil? || v.is_a?(t) if typed_struct_typedef? t

      return v.all? { |el| type_correct?(t[0], el) } if array_typedef? t

      raise ArgumentError, "t #{t.inspect} is not supported type"
    end

    RubyJSON = JSON
  end
end

module TypedSerde
  module JSON
    def marshal(v)
      Typed::Internal::RubyJSON.generate v
    end

    def unmarshal(data, obj)
      Typed::Internal::RubyJSON.parse data, object_class: obj
    end

    module_function :marshal, :unmarshal
  end
end
