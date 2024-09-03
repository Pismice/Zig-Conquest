<script setup>
</script>

<template>
  <main>
    <div class="flex">
      <div class="w-52 h-screen flex-shrink-0">
        <span class="text-2xl font-bold text-yellow-400">Zig Conquest</span>
        <nav class="flex flex-col">
          <RouterLink to="/" class="p-2">Home</RouterLink>
          <RouterLink to="/myvillage" class="p-2">My village</RouterLink>
        </nav>
      </div>
      <router-view></router-view>
    </div>
  </main>
</template>

<style scoped></style>
