/**
 *
 * Extracts the form values and returns them as a JSON
 *
 * @param form_cells as an array of HTMLElements
 * @returns form_content as a JSON
 */
function extract_content(form_cells) {
    const form_content = {};

    form_cells.forEach(cell => {
        form_content[cell.nextElementSibling.textContent] = cell.value;
    });

    return form_content;
}

/**
 *
 * Displays a message overlaying the form_element.
 *
 * @param form_element
 * @param msg Message to display
 * @param success 1 for success, 0 of pending status and -1 on error
 */
function set_status(form_element, msg, success) {

    form_element.classList.add('input-container-sending')
    form_element.style.setProperty('--content_msg', "'" + msg + "'")

    switch (success) {

        case -1: // on error
            form_element.style.setProperty('color', "#e5352c")
            break;

        case 0: // pending
            break

        case 1: // on success
            form_element.style.setProperty('color', "#97bf0d")
            break

    }


}

/**
 * Displays a message overlaying the form_element and removes the message after 2.5s.
 *
 * @param form_element
 * @param msg Message to display
 * @param success 1 for success, 0 of pending status and -1 on error
 *
 */
function set_timed_status(form_element, msg, success) {

    set_status(form_element, msg, success);

    // remove status after 2.5s
    setTimeout(() => {
        form_element.classList.remove('input-container-sending')
        form_element.style.setProperty('color', "#585858")
    }, 5_000)

}


/**
 *
 * Sends the form content to the backend server, iff the form input is valid.
 * Confirms the status to the user by displaying a message over the form element.
 *
 * @param uuid uuid of the form HTMLElement
 */
function send_message(uuid, backend_url) {

    const form_element = document.getElementById(uuid);

    if (!form_element.checkValidity())
        return;

    console.log('Send message for ', uuid)
    const form_cells = document.querySelectorAll(`#${uuid} > div > input, #${uuid} > div > textarea`);

    const form_content = extract_content(form_cells);
    console.log(form_content);

    // Inform user that the form was send to the server
    set_status(form_element, 'Deine Nachricht wird gesendet...', 0)

    fetch(`${backend_url}/form/submission`, {

        method: "POST",
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(form_content)

    }).then(res => {

        console.log("Request complete! response:", res);

        if (res.status === 200) {
            set_timed_status(form_element, 'Deine Nachricht wurde erfolgreich übertragen.', 1)
            reset_form(form_element)
        } else
            throw res;


    }).catch(err => {

        console.log("Request failed! response:", err);
        set_timed_status(form_element, 'Es ist eine Fehler aufgetreten. Das Formular wurde nicht übermittelt!', -1)

    });


}

/**
 * Resets the form to its initial state.
 * @param form_element
 */
function reset_form(form_element) {

    const form_cells = document.querySelectorAll(`#${form_element.id} > div > input, #${form_element.id} > div > textarea`);

    form_cells.forEach(cell => {
        cell.setAttribute('value', '');
        cell.value = ''
    });

}