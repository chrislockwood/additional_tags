class AdditionalTagsRemoveUnusedTagJob < AdditionalTagsJob
  def perform
    AdditionalTags::Tags.remove_unused_tags
  end
end
