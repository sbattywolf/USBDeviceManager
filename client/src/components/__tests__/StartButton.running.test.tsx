/**
 * @jest-environment jsdom
 */

import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { StartButton } from '../StartButton';

const stopMut = jest.fn();
const restartMut = jest.fn();

jest.mock('../../hooks/use-config-status', () => ({
  useConfigStatus: (id: number) => ({ data: { id, isRunning: true }, isLoading: false })
}));

jest.mock('../../hooks/use-start-software', () => ({
  useStartSoftware: () => ({ mutate: jest.fn(), isPending: false })
}));

jest.mock('../../hooks/use-stop-software', () => ({
  useStopSoftware: () => ({ mutate: stopMut, isPending: false })
}));

jest.mock('../../hooks/use-restart-software', () => ({
  useRestartSoftware: () => ({ mutate: restartMut, isPending: false })
}));

describe('StartButton when running', () => {
  beforeEach(() => {
    stopMut.mockClear();
    restartMut.mockClear();
  });

  test('renders Stop and Restart and confirms stop', () => {
    render(<StartButton configId={5} friendlyName="Demo App"/>);
    const stopBtn = screen.getByTestId('button-stop-software-5');
    const restartBtn = screen.getByTestId('button-restart-software-5');
    expect(stopBtn).toBeTruthy();
    expect(restartBtn).toBeTruthy();

    // Open stop dialog
    fireEvent.click(stopBtn);
    const confirm = screen.getByTestId('confirm-stop-5');
    expect(confirm).toBeTruthy();

    fireEvent.click(confirm);
    expect(stopMut).toHaveBeenCalledWith(5);
  });

  test('confirms restart', () => {
    render(<StartButton configId={6} friendlyName="Demo App 2"/>);
    const restartBtn = screen.getByTestId('button-restart-software-6');
    fireEvent.click(restartBtn);
    const confirm = screen.getByTestId('confirm-restart-6');
    fireEvent.click(confirm);
    expect(restartMut).toHaveBeenCalledWith(6);
  });
});
