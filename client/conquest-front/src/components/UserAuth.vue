<script setup>
import { onMounted } from 'vue'

const origin = "http://localhost:1950/";

function register() {
  const data = {
    username: 'v1111',
    password: 'mypassword'
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
      console.log('Success:', data);
    })
    .catch(error => {
      console.error('Error:', error);
    });
}

onMounted(() => {
  register()
})
</script>

<template>
  You are not connected because you dont have cookie _ <span><b> session_id</b></span> set !
</template>
