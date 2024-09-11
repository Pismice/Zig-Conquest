<script setup>
import { onMounted, ref } from 'vue'


const origin = "http://localhost:1950/";
const village = ref({});

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
      village.value = data[0];
    })
    .catch(error => {
      console.error('There has been a problem with your fetch operation:', error);
    });
}

function buildGoldMine() {
  fetch(origin + "game/create_building", {
    credentials: 'include', // Send cookies with the request
    method: 'POST',
  })
    .then(response => {
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    })
    .then(data => {
      console.log(data);
      if (data.success == true) {
        console.log("Building created successfully");
      } else {
        console.log("Building creation failed");
      }
    })
    .catch(error => {
      console.error('There has been a problem with your fetch operation:', error);
    });

}

onMounted(() => {
  fetchVillage()
  setInterval(fetchVillage, 5000);
})

</script>

<template>
  <div>
    <h1>{{ village.name }} is level {{ village.level }}</h1>
    <div>The coordinates of your village are: {{ village.x_position }} {{ village.y_position }}</div>
    <div>You have {{ village.gold }} gold and {{ village.space_capacity }} space capacity.</div>
    <button @click="buildGoldMine"
      class="bg-yellow-500 text-white font-bold py-2 px-4 rounded shadow-lg hover:bg-yellow-600 focus:outline-none focus:ring-2 focus:ring-yellow-400 focus:ring-opacity-50 transition duration-300 ease-in-out">
      Build a gold mine
    </button>
  </div>
</template>
