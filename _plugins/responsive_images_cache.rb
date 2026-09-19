require_relative 'utils/derivative_cache'
require_relative 'utils/build_stats'

# Teaches responsive-images-for-jekyll to use the same content-keyed cache as the
# gallery plugin.
#
# The gem decides whether an image has to be rebuilt by comparing mtimes, which
# always says "rebuild" in CI - see DerivativeCache for why. Everything the gem
# writes lands under imgs/ next to the gallery images, so the two pipelines can
# share one manifest.
#
# This lives here rather than in the gem so that it stays next to the cache it
# talks to; it should move upstream into
# https://github.com/wp99cp/responsive_images_for_jekyll eventually.
module ResponsiveImagesCache

  # The gem's own signature: (src_path, dest_path)
  def _must_create?(src_path, dest_path)
    DerivativeCache.reference(dest_path)

    if DerivativeCache.fresh?(dest_path, DerivativeCache.source_key(src_path))
      BuildStats.count(:local_reused)
      return false
    end

    true
  end

  # The gem's own signature: (src_path, img_dim, dest_path, img_desc)
  def _process_img(src_path, img_dim, dest_path, img_desc)
    BuildStats.count(:local_built)
    BuildStats.time(:convert) { super }
    DerivativeCache.record(dest_path, DerivativeCache.source_key(src_path))
  end

end

Jekyll::ImageInlineTag.prepend(ResponsiveImagesCache)
