import { TestBed } from '@angular/core/testing';

import { SharedState } from './shared-state';

describe('SharedState', () => {
  let service: SharedState;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(SharedState);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
