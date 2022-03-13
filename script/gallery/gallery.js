import PhotoSwipeLightbox from "/script/gallery/photoswipe-lightbox.esm.min.js";

var getUrl = window.location;
var baseUrl = getUrl.protocol + "//" + getUrl.host + "/" + getUrl.pathname.split('/')[1];


const lightbox = new PhotoSwipeLightbox({
    // may select multiple "galleries"
    gallery: '#gallery-simple',
    showHideAnimationType: 'zoom',
    // Elements within gallery (slides)
    children: 'a',
    zoom: false,
    loop: true,
    preload: [2, 3], // Lazy loading of nearby slides based on direction of movement.
    pswpModule: baseUrl + 'script/gallery/photoswipe.esm.min.js'
});
lightbox.init();


