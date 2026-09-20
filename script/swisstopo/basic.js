import {
    AttributionControl,
    Map as MapLibre,
    Marker,
    NavigationControl,
} from 'https://unpkg.com/maplibre-gl@6.4.1/dist/maplibre-gl.mjs';

const base_url = window.location.origin;

// Swisstopo publishes its basemap as a MapLibre style, and MapLibre is what
// renders it correctly. The ArcGIS SDK this used to run on only implements part
// of the style spec: it ignored the zoom-dependent paint functions, so buildings,
// street names and place labels never appeared, and it stopped asking for tiles
// one zoom level above the data, leaving the map emptier the further you zoomed
// in. The same swisstopo sources are used in conveniat-webpage through MapLibre.

// The pages give a map scale ("1:6500"), which is what the old SDK took, so
// convert it to the zoom level MapLibre wants. The scale values in the pages
// were chosen against ArcGIS, whose scales come from a tile scheme of 256px
// tiles; MapLibre's tiles are 512px, which is exactly one zoom level.
const WEB_MERCATOR_SCALE_AT_ZOOM_0 = 559_082_264.028;

// Rounded because the old view snapped to whole zoom levels, and the scales in
// the pages were picked to look right after that snapping. Keeping the fraction
// would frame every existing map slightly tighter than its author chose.
const zoom_for_scale = scale =>
    Math.round(Math.log2(WEB_MERCATOR_SCALE_AT_ZOOM_0 / scale) - 1);

const map = new MapLibre({
    container: 'viewDiv',
    style: base_url + '/script/swisstopo/style.json',
    center: map_center,
    zoom: zoom_for_scale(scale),

    // The old view refused to zoom out past 1:25000. Keep that: swisstopo only
    // has data for Switzerland, so zooming out far enough just empties the map.
    minZoom: zoom_for_scale(25_000),

    // Scrolling over the map should scroll the page, not zoom; MapLibre asks for
    // ctrl/⌘ or two fingers instead, and says so when you try.
    cooperativeGestures: true,

    dragRotate: false,
    pitchWithRotate: false,
    touchPitch: false,

    attributionControl: false,
});

map.addControl(new NavigationControl({showCompass: false}), 'top-left');
map.addControl(new AttributionControl({
    compact: true,
    customAttribution: '© Daten:MapTiler, OpenStreetMap contributors, swisstopo',
}));

points.forEach(pkt => {
    const marker = document.createElement('img');
    marker.src = base_url + '/_template_assets/weblogo.svg';
    marker.alt = '';

    // The logo is a 600x600 svg, so the marker needs to be told how big it
    // should be. display:block stops the browser from reserving space for a
    // text baseline underneath it, which would push the logo off its point.
    marker.style.width = '32px';
    marker.style.height = '32px';
    marker.style.display = 'block';

    new Marker({element: marker}).setLngLat(pkt).addTo(map);
});
