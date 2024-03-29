// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"
import public_css from "../css/public_front.css"

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
import NProgress from "nprogress"

let Hooks = {}

Hooks.draggable_user_hook = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
      e.dataTransfer.setData("text/plain", e.target.id); // save the elements id as a payload
    })
  }
}

Hooks.draggable_search_user_hook = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
      e.dataTransfer.setData("text/plain", e.target.id); // save the elements id as a payload
    })
  }
}

Hooks.element_dropzone = {
  mounted() {
    this.el.addEventListener("dragover", e => {
      e.preventDefault();
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
    })
    this.el.addEventListener("drop", e => {
      e.preventDefault();
      var target = e.currentTarget.id
      var element_id = e.dataTransfer.getData("text/plain")
      // var element_id = e.currentTarget.parentNode.id
      this.pushEvent("element-dropped", {target: target, element_id: element_id});
    })
  }
}

Hooks.draggable_role_hook = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
      e.dataTransfer.setData("text/plain", e.target.id); // save the elements id as a payload
    })
  }
}

Hooks.role_dropzone = {
  mounted() {
    this.el.addEventListener("dragover", e => {
      e.preventDefault();
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
    })

    this.el.addEventListener("dragover", e => {
      e.preventDefault();
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
    })

    this.el.addEventListener("drop", e => {
      e.preventDefault();
      var role_id = e.dataTransfer.getData("text/plain").replace("available-role-", "")
      var user_id = e.currentTarget.parentNode.id.replace("user-", "")
      this.pushEvent("add-role", {user_id: user_id, role_id: role_id});
    })
  }
}

function get_placeholder() {
  let li = document.createElement('div');
  li.className = 'track-placeholder';
  return li;
}

function remove_all_placeholders() {
  var ph = document.getElementsByClassName("track-placeholder")
  while (ph[0]) {
    ph[0].parentNode.removeChild(ph[0])
  }
}


Hooks.draggable_mx_track_hook = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "copy";
      e.dataTransfer.dropEffect = "copy";
      e.dataTransfer.setData("text/plain", e.target.id); // save the elements id as a payload
    })
  }
}

Hooks.draggable_server_track_hook = {
  mounted() {
    this.el.addEventListener("dragstart", e => {
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.dropEffect = "move";
      e.dataTransfer.setData("text/plain", e.target.id);
    })
    this.el.addEventListener("dragover", e => {
      document.querySelectorAll(".row").forEach(element => element.classList.remove("sss"))
      remove_all_placeholders(document)
      e.target.parentNode.insertBefore(get_placeholder(), e.target.nextSibling);
    })
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
      let tracklistArray = Array.prototype.slice.call(e.currentTarget.children)
      let index = tracklistArray.indexOf(ph)
      var data = e.dataTransfer.getData("text/plain")
      let oldIndex = tracklistArray.indexOf(document.getElementById(data))

      if (data.startsWith("mx")) {
        this.pushEvent("add-mx-track", {data, index: index+1});
      } else if (data.startsWith("track")) {
        if (oldIndex < index) { index = index - 1}
        this.pushEvent("reorganize-tracklist", {data, index: index})
      } {
      }
    })
  }
}
 let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

liveSocket.connect()
