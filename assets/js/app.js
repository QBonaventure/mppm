// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

import {Socket} from "phoenix"
import LiveSocket from "phoenix_live_view"

let Hooks = {}
Hooks.draggable_mx_track_hook = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
      e.dataTransfer.setData("text/plain", e.target.id); // save the elements id as a payload
    })
  }
}

function get_placeholder() {
  let li = document.createElement('div');
  li.className = 'track-placeholder';
  return li;
}

function remove_all_placeholders(document) {
  var ph = document.getElementsByClassName("track-placeholder")
  while (ph[0]) {
    ph[0].parentNode.removeChild(ph[0])
  }
}

Hooks.draggable_server_track_hook = {
  mounted() {
    this.el.addEventListener("dragover", e => {
      document.querySelectorAll(".row").forEach(element => element.classList.remove("sss"))
      // classList.remove("sss");
      remove_all_placeholders(document)
      e.target.parentNode.insertBefore(get_placeholder(), e.target.nextSibling);
    })
    // this.el.addEventListener("dragleave", e => {
    //   e.target.classList.remove("sss");
    // })
  }
}

Hooks.track_dropzone = {
  mounted() {
    this.el.addEventListener("dragstart", e => {

      e.currentTarget.classList.add("sss");
    })

    this.el.addEventListener("dragover", e => {
      e.preventDefault();
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
    })

    this.el.addEventListener("drop", e => {
      e.preventDefault();
      let ph = document.getElementsByClassName("track-placeholder")[0]
      let index = Array.prototype.slice.call(e.currentTarget.children).indexOf(ph)

      var data = e.dataTransfer.getData("text/plain");
      this.pushEvent("add-mx-track", {data, index: index});
      // this.el.appendChild(e.view.document.getElementById(data));
    })
  }
}
 let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})
liveSocket.connect()
