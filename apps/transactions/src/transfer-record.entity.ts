import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('transfer_records')
export class TransferRecord {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  transferId!: string;

  @Column()
  fromAccountId!: string;

  @Column()
  toAccountId!: string;

  @Column({ type: 'decimal', precision: 12, scale: 2 })
  amount!: number;

  @Column({ default: 'pending' })
  status!: string; // 'completed' | 'failed'

  @Column({ nullable: true })
  failReason!: string;

  @CreateDateColumn()
  processedAt!: Date;
}
