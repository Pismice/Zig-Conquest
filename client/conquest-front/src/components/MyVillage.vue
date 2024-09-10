<script setup>
import { onMounted } from 'vue'


const origin = "http://localhost:1950/";

function fetchVillage() {
  console.log("fetching village data")
  fetch(origin + "game/village", {
    credentials: 'include', // Send cookies with the request
  })
    .then(response => {
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    })
    .then(data => {
      console.log(data);
    })
    .catch(error => {
      console.error('There has been a problem with your fetch operation:', error);
    });
}

onMounted(() => {
  fetchVillage()
})

</script>

<template>
  village
</template>
