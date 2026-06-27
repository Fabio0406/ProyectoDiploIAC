import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

@Entity('accounts')
export class Account {
  @PrimaryGeneratedColumn('uuid')
  id: string | undefined;

  @Column({ length: 120 })
  owner: string | undefined;

  @Column({ type: 'decimal', precision: 18, scale: 2, default: 0 })
  balance: number | undefined;

  @CreateDateColumn()
  createdAt: Date | undefined;

  @UpdateDateColumn()
  updatedAt: Date | undefined;
}