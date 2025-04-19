module Typed
    class TypedStruct
        def self.__attributes
            unless defined? @attributes then
                @attributes = {}
            end

            @attributes
        end

        def self.define(name, type)
            is_typed_struct = false
            if type.respond_to? :superclass
            is_typed_struct = type.superclass == TypedStruct
            end

            unless Typed.zero_values().key?(type) || is_typed_struct
                raise ArgumentError, "unsupported type #{type}"
            end

            __attributes[name] = type

            attr_reader name

            # attr_writer は型の制限なしに代入できてしまうので、独自に型チェックを実装する
            # safe_assign と異なり、= で代入したときは型チェックに失敗したら例外を投げる
            define_method "#{name}=" do |v|
                ok = self.safe_assign name, v
                unless ok then
                raise TypeError, "cannot assign #{v} to #{self.class}.#{name}"
                end
            end
        end

        def initialize(init = {})
            defined_attributes = self.class.__attributes

            defined_attributes.each do |name, type|
                zero = Typed.zero_values()[type]
                value = init.fetch name, zero
                instance_variable_set "@#{name}", value
            end
        end

        # 代入時に型チェックをし、成功したら true、失敗したら false を返す
        def safe_assign(to, value)
            t = self.class.__attributes[to]
            if t == nil then
            return false
            end

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
            if Typed.typed_struct_type? t
                valid = value.is_a? t
            end

            unless valid then
            return false
            end

            instance_variable_set "@#{to}", value

            return true
        end
    end

    private

    def self.zero_values
        {
            int: 0,
            string: "",
            any: nil,
        }.freeze
    end

    def self.typed_struct_type?(t)
        unless t.respond_to? :superclass
            return false
        end

        unless t.superclass == Typed::TypedStruct
            return false
        end

        return true
    end

end
