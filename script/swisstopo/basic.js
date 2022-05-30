const base_url = window.location.origin;

fetch(base_url + '/script/swisstopo/style.json').then(resp => resp.json().then(style => {
    require([
            "esri/Map",
            "esri/views/MapView",
            "esri/layers/VectorTileLayer",
            "esri/layers/WMTSLayer",
            "esri/core/watchUtils",
            "esri/layers/support/TileInfo",
            "esri/Graphic",
            "esri/layers/GraphicsLayer"],
        (Map, MapView, VectorTileLayer, WMTSLayer, watchUtils, TileInfo, Graphic, GraphicsLayer) => {

            const cevi_symbol = {
                type: "picture-marker", url: base_url + "/_template_assets/weblogo.svg", width: "32px", height: "32px"
            };

            const tileLayer = new VectorTileLayer({
                style: style, copyright: "© Daten:MapTiler, OpenStreetMap contributors, swisstopo"
            });


            const graphicsLayer = new GraphicsLayer();
            points.forEach(pkt => {
                const pointGraphic = new Graphic({
                    geometry: {type: "point", longitude: pkt[0], latitude: pkt[1]},
                    symbol: cevi_symbol
                });
                graphicsLayer.add(pointGraphic);
            });

            // Create a Map
            const map = new Map({layers: [tileLayer, graphicsLayer]});

            // Make map view and bind it to the map
            new MapView({
                container: "viewDiv",
                map: map,
                constraints: {lods: TileInfo.create({}).lods, maxScale: 0, minScale: 25_000},
                scale: scale,
                center: map_center,
                navigation: {
                    gamepad: {
                        enabled: false
                    },
                    browserTouchPanEnabled: false,
                    momentumEnabled: false,
                    mouseWheelZoomEnabled: false
                }
            });

        });

}));
