<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter();
const origin = "http://localhost:1950/";
var us = ref('');
var pa = ref('');

function register() {
  const data = {
    username: us.value,
    password: pa.value
  };

  const formBody = Object.keys(data).map(key =>
    encodeURIComponent(key) + '=' + encodeURIComponent(data[key])
  ).join('&');

  fetch(origin + "auth/register", {
    credentials: 'include',
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: formBody
  })
    .then(response => response.json())
    .then(data => {
      console.log('Server response:', data);
      console.log(us.value + ' ' + pa.value);
      router.push('/myvillage');
    })
    .catch(error => {
      console.error('Error:', error);
    });
}

onMounted(() => {
})
</script>

<template>
  <div>
    You are not connected because you dont have cookie _ <span><b> session_id</b></span> set !
    <div>
      <label for="username">Username:</label>
      <input id="username" type="text" v-model="us" class="bg-purple-950">
    </div>
    <div>
      <label for="password">Password:</label>
      <input id="password" type="text" v-model="pa" class="bg-purple-800">
    </div>
    {{ us }} {{ pa }}
    <button @click="register()">Register</button>
  </div>
</template>
