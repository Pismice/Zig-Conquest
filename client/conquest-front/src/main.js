import './assets/main.css'
import Cookies from 'js-cookie'

import { createMemoryHistory, createRouter } from 'vue-router'
import { createApp } from 'vue'
import App from './App.vue'
import MyVillage from './components/MyVillage.vue'
import TheWelcome from './components/TheWelcome.vue'
import UserAuth from './components/UserAuth.vue'
import AttackablePlayers from './components/AttackablePlayers.vue'

const routes = [
  { path: '/', component: TheWelcome },
  { path: '/userauth', component: UserAuth },
  { path: '/myvillage', component: MyVillage },
  { path: '/attack', component: AttackablePlayers },
]

const router = createRouter({
  history: createMemoryHistory(),
  routes,
})

router.beforeEach((to) => {
  if (to.path != "/userauth" && Cookies.get("session_id") == undefined) {
    // if the user is not connected and try to access anything but /userauth
    return { path: "/userauth" }
  } else if (to.path == "/userauth" && Cookies.get("session_id") != undefined) {
    // if the user is connected and try to access /userauth
    return { path: "/myvillage" }
  }
})

createApp(App).use(router).mount('#app')
