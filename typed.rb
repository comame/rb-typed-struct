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
      zero = Typed::Internal.zero_values[type]
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
    def supported_primitives
      %i[int string any]
    end

    def zero_values
      {
        int: 0,
        string: '',
        any: nil
      }
    end

    def supported_type?(t)
      return true if t.is_a?(Symbol) && supported_primitives.include?(t)

      return false unless t.respond_to? :superclass
      return false unless t.superclass == TypedStruct

      true
    end

    def type_correct?(t, v)
      raise ArgumentError, "t #{t.inspect}is not supported type" unless supported_type?(t)

      case t
      when :int
        return v.is_a? Integer
      when :string
        return v.is_a? String
      when :any
        return true
      end

      # プリミティブでないなら、常に TypedStruct であるはず
      v.nil? || v.is_a?(t)
    end

    RubyJSON = JSON

    module_function :supported_primitives, :zero_values, :supported_type?, :type_correct?
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
