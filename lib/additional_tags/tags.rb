module AdditionalTags
  class Tags
    class << self
      def available_tags(klass, options = {})
        user = options[:user].presence || User.current

        scope = ActsAsTaggableOn::Tag.where({})
        scope = scope.where("#{Project.table_name}.id = ?", options[:project]) if options[:project]
        if options[:permission]
          scope = scope.where(tag_access(options[:permission], user))
        elsif options[:visible_condition]
          scope = scope.where(klass.visible_condition(user))
        end
        scope = scope.where("LOWER(#{TAG_TABLE_NAME}.name) LIKE ?", "%#{options[:name_like].downcase}%") if options[:name_like]
        scope = scope.where("#{TAG_TABLE_NAME}.name=?", options[:name]) if options[:name]
        scope = scope.where("#{TAGGING_TABLE_NAME}.taggable_id!=?", options[:exclude_id]) if options[:exclude_id]
        scope = scope.where(options[:where_field] => options[:where_value]) if options[:where_field].present? && options[:where_value]

        columns = ["#{TAG_TABLE_NAME}.*",
                   "COUNT(DISTINCT #{TAGGING_TABLE_NAME}.taggable_id) AS count"]

        order = options[:order] == 'DESC' ? 'DESC' : 'ASC'
        columns << "MIN(#{TAGGING_TABLE_NAME}.created_at) AS last_created" if options[:sort_by] == 'last_created'

        order_column = case options[:sort_by]
                       when 'last_created'
                         'last_created'
                       when 'count'
                         'count'
                       else
                         "#{TAG_TABLE_NAME}.name"
                       end

        scope.select(columns.join(', '))
             .joins(tag_for_joins(klass, options))
             .group("#{TAG_TABLE_NAME}.id, #{TAG_TABLE_NAME}.name").having('COUNT(*) > 0')
             .order(Arel.sql("#{order_column} #{order}"))
      end

      def all_type_tags(klass, options = {})
        ActsAsTaggableOn::Tag.where({})
                             .joins(tag_for_joins(klass, options))
                             .distinct
                             .order("#{TAG_TABLE_NAME}.name")
      end

      def tag_to_joins(klass)
        table_name = klass.table_name

        joins = ["JOIN #{TAGGING_TABLE_NAME} ON #{TAGGING_TABLE_NAME}.taggable_id = #{table_name}.id" \
                 " AND #{TAGGING_TABLE_NAME}.taggable_type = '#{klass}'"]
        joins << "JOIN #{TAG_TABLE_NAME} ON #{TAGGING_TABLE_NAME}.tag_id = #{TAG_TABLE_NAME}.id"

        joins
      end

      def remove_unused_tags
        ActsAsTaggableOn::Tag.where.not(id: ActsAsTaggableOn::Tagging.select(:tag_id).distinct)
                             .each(&:destroy)
      end

      # sort tags alphabetically with special characters support
      def sort_tags(tags)
        tags.sort! do |a, b|
          ActiveSupport::Inflector.transliterate(a.downcase) <=> ActiveSupport::Inflector.transliterate(b.downcase)
        end
      end

      # sort tag_list alphabetically with special characters support
      def sort_tag_list(tag_list)
        tag_list.to_a.sort! do |a, b|
          ActiveSupport::Inflector.transliterate(a.name.downcase) <=> ActiveSupport::Inflector.transliterate(b.name.downcase)
        end
      end

      private

      def tag_for_joins(klass, options = {})
        table_name = klass.table_name

        joins = ["JOIN #{TAGGING_TABLE_NAME} ON #{TAGGING_TABLE_NAME}.tag_id = #{TAG_TABLE_NAME}.id"]
        joins << "JOIN #{table_name} " \
                 "ON #{table_name}.id = #{TAGGING_TABLE_NAME}.taggable_id AND #{TAGGING_TABLE_NAME}.taggable_type = '#{klass}'"

        if options[:project_join]
          joins << options[:project_join]
        elsif options[:project] || !options[:without_projects]
          joins << "JOIN #{Project.table_name} ON #{table_name}.project_id = #{Project.table_name}.id"
        end

        joins
      end

      def tag_access(permission, user)
        projects_allowed = if permission.nil?
                             Project.visible.ids
                           else
                             Project.where(Project.allowed_to_condition(user, permission)).ids
                           end

        if projects_allowed.present?
          "#{Project.table_name}.id IN (#{projects_allowed.join ','})" unless projects_allowed.empty?
        else
          '1=0'
        end
      end
    end
  end
end
