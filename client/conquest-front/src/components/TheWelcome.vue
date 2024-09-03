<script setup>
import { ref, onMounted } from 'vue'

let rankings = ref([]);
let nb_players = ref(0);

const origin = "http://localhost:1950/";


function fetchRanking() {
  fetch(origin + "game/ranking")
    .then(response => {
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    })
    .then(data => {
      if (Array.isArray(data) && Array.isArray(data[0])) {
        rankings.value = data[0];
        nb_players.value = data[0].length;
        console.log(rankings.value);
      } else {
        throw new Error('Unexpected data format');
      }
    })
    .catch(error => {
      'Failed to fetch rankings: ' + error.message;
    })
    .finally(() => {
    });
}



onMounted(() => {
  fetchRanking()
})

</script>

<template class="flex flex-col">
  <div class="flex flex-col">
    <h1 class="underline"> Welcome to Zig Conquest ! </h1>
    <p> Here are the top {{ nb_players }} players: </p>
    <ul>
      <li v-for="(player, index) in rankings" :key="player.id">
        {{ index + 1 }}: {{ player.username }} - {{ player.gold }}
      </li>
    </ul>
  </div>
</template>
