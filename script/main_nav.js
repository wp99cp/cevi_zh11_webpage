document.addEventListener("DOMContentLoaded", function () {

    let menu_items = document.querySelectorAll('.menu-item');

    // for every menu_item with a submenu add a click listener to select the checkbox
    menu_items.forEach(menu_item => {

        // check if element with class 'active' is present in menu_item
        if (menu_item.querySelector('.active')) {

            if (menu_item.querySelector('.submenu-opener')) {
                menu_item.querySelector('.submenu-opener').checked = true;
            }
        }

    });
})