module ActiveRecord
  module ModelTranslations
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def translates(*attributes)
        attributes = attributes.map{|attribute| attribute.to_sym}

        unless included_modules.include? InstanceMethods
          include InstanceMethods

          define_method :translated_attributes do
            @translated_attributes
          end

          after_save do |record|
            record.update_translations!
          end

          define_method :locales do
            return [] if new_record?
            type = self.class.to_s.downcase
            statement = "SELECT * FROM #{type}_translations WHERE #{type}_id = #{id}"
            logger.debug(statement)
            translations = ActiveRecord::Base.connection.select_all(statement)
            translations.map{|t| t['locale'].to_sym}.select{|locale| I18n.locales.include?(locale)}
          end
        end

        attributes.each do |attribute|
          define_method "#{attribute}=".to_sym do |value|
            @translated_attributes ||= {}
            @translated_attributes[attribute] = value
          end

          define_method attribute do
            @translated_attributes ||= {}
            return @translated_attributes[attribute] if @translated_attributes[attribute]
            return nil if new_record?
            type = self.class.to_s.downcase
            statement = "SELECT * FROM #{type}_translations WHERE #{type}_id = #{id}"
            logger.debug(statement)
            translations = ActiveRecord::Base.connection.select_all(statement)
            translation = translations.find{|t| t["locale"] == I18n.locale.to_s}
            translation = translations.find{|t| t["locale"] == I18n.default_locale.to_s} unless translation
            translation = translations.first unless translation
            if translation
              translation.
                select{|k, v| attributes.include?(k.to_sym) && !@translated_attributes.keys.include?(k.to_sym)}.
                each{|k, v| @translated_attributes[k.to_sym] = v}
            end
            @translated_attributes[attribute]
          end
        end
      end
    end

    module InstanceMethods
      def update_translations!
        return unless @translated_attributes and not @translated_attributes.empty?
        type = self.class.to_s.downcase
        statement = "SELECT * FROM #{type}_translations WHERE #{type}_id = #{id} AND locale = '#{I18n.locale}'"
        logger.debug(statement)
        translation = ActiveRecord::Base.connection.select_all(statement).first
        if translation
          statement = "UPDATE #{type}_translations SET "
          statement << "updated_at = '#{DateTime.now.to_s(:db)}', "
          statement << @translated_attributes.map do |key, value|
            v = value ? value.gsub('"', '\"') : nil
            "#{key} = \"#{v}\""
          end.join(', ')
          statement << " WHERE id = #{translation['id']}"
        else
          keys = @translated_attributes.keys
          statement = "INSERT INTO #{type}_translations "
          statement << "(#{type}_id, locale, created_at, updated_at, " + keys.join(', ') + ") "
          statement << "VALUES (#{id}, '#{I18n.locale}', '#{DateTime.now.to_s(:db)}', '#{DateTime.now.to_s(:db)}', "
          statement << keys.map do |key|
            v = @translated_attributes[key] ? @translated_attributes[key].gsub('"', '\"') : nil
            "\"#{v}\""
          end.join(', ') + ")"
        end
        logger.debug(statement)
        ActiveRecord::Base.connection.execute(statement)
      end
    end
  end
end
