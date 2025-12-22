/**
 * @jest-environment jsdom
 */

import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { StartButton } from '../StartButton';

// Mock hooks used by StartButton
jest.mock('../../hooks/use-config-status', () => ({
  useConfigStatus: (id: number) => ({ data: { id, isRunning: false }, isLoading: false })
}));

jest.mock('../../hooks/use-start-software', () => ({
  useStartSoftware: () => ({ mutate: jest.fn(), isPending: false })
}));

jest.mock('../../hooks/use-stop-software', () => ({
  useStopSoftware: () => ({ mutate: jest.fn(), isPending: false })
}));

jest.mock('../../hooks/use-restart-software', () => ({
  useRestartSoftware: () => ({ mutate: jest.fn(), isPending: false })
}));

describe('StartButton UI', () => {
  test('renders Start when not running', () => {
    render(<StartButton configId={1} friendlyName="My App" />);
    expect(screen.getByTestId('button-start-software-1')).toBeTruthy();
  });
});
