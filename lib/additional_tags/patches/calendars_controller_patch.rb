module AdditionalTags
  module Patches
    module CalendarsControllerPatch
      extend ActiveSupport::Concern

      included do
        helper :additional_tags
        helper :additional_tags_issues

        include AdditionalTagsHelper
      end
    end
  end
end
