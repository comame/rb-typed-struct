# frozen_string_literal: true

class TypedStruct
  class << self
    def define(name, type)
      is_typed_struct = false
      is_typed_struct = type.superclass == TypedStruct if type.respond_to? :superclass

      raise ArgumentError, "unsupported type #{type}" unless __zero_values.key?(type) || is_typed_struct

      __attributes[name] = type

      attr_reader name

      # safe_assign と異なり、= で代入したときは型チェックに失敗したら例外を投げる
      define_method "#{name}=" do |v|
        assign! name, v
      end
    end

    def __zero_values
      {
        int: 0,
        string: '',
        any: nil
      }.freeze
    end

    def __typed_struct_type?(t)
      return false unless t.respond_to? :superclass
      return false unless t.superclass == TypedStruct

      true
    end

    def __attributes
      @__attributes ||= {}
    end
  end

  # インスタンス化時に初期値を指定する場合、{ [key] => value } 形式で渡す
  def initialize(init = {})
    self.class.__attributes.each do |name, type|
      zero = self.class.__zero_values[type]
      value = init.fetch name, zero
      assign! name, value
    end
  end

  # JSON に変換
  def to_json(*args)
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

    raise TypeError, "cannot assign #{value} to #{self.class}.#{to}"
  end

  def safe_assign(to, value)
    t = self.class.__attributes[to]
    return false if t.nil?

    valid = false
    # プリミティブな型のチェック
    case t
    when :int
      valid = value.is_a? Integer
    when :string
      valid = value.is_a? String
    when :any
      valid = true
    end
    # TypedStruct のチェック
    valid = value.is_a? t if self.class.__typed_struct_type? t

    return false unless valid

    instance_variable_set "@#{to}", value

    true
  end
end
