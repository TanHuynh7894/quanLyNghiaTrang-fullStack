import { Routes } from '@angular/router';
import { Home } from '../app/home/home';

export const routes: Routes = [
  {
    path: '',
    component: Home,
    title: 'Trang chủ',
    pathMatch: 'full',
  },
  {
    path: 'map-pages',
    loadComponent: () =>
      import('../app/map-page/map-page').then(m => m.MapPageComponent),
    title: 'Bản đồ',
  },
  {
    path: '**',
    redirectTo: '',
    pathMatch: 'full',
  },
];
