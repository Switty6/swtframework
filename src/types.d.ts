/* eslint-disable @typescript-eslint/no-explicit-any */
declare const mp: any;

declare namespace RageMP {
  interface Vector3 {
    x: number;
    y: number;
    z: number;
  }

  interface PlayerMp {
    id: number;
    name: string;
    position: Vector3;
    dimension: number;
    health: number;
    armour: number;
    vehicle?: any;
    call: (event: string, ...args: any[]) => void;
    outputChatBox: (message: string) => void;
    giveWeapon: (hash: string, ammo: number) => void;
    removeAllWeapons: () => void;
    setVariable: (key: string, value: any) => void;
    getVariable: (key: string) => any;
    spawn: (position: Vector3) => void;
  }
}
