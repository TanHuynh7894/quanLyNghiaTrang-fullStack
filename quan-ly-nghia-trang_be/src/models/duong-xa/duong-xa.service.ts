// src/duong-xa/duong-xa.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { DuongXa } from './entities/duong-xa.entity';

interface NodeRow {
  id: number; // alias từ fid
}

interface RouteRow {
  geojson: string | null;
  total_cost: number | null;
}

interface StepRow {
  seq: number;
  node: number;
  edge: number;
  cost: number;
  agg_cost: number;
}

export interface RouteResponse {
  fromNodeId: number;
  toNodeId: number;
  totalCost: number;
  geojson: string;
  steps: StepRow[];
}

@Injectable()
export class DuongXaService {
  constructor(
    @InjectRepository(DuongXa)
    private readonly duongXaRepo: Repository<DuongXa>,

    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  // 🔍 Tìm node gần nhất (dùng fid làm node-id)
  private async findNearestNodeId(lat: number, lng: number): Promise<number> {
    const rows = await this.dataSource.query<NodeRow[]>(
      `
        SELECT fid AS id
        FROM nodes
        ORDER BY geom <-> ST_SetSRID(ST_Point($1, $2), 4326)
        LIMIT 1;
      `,
      [lng, lat], // ST_Point(longitude, latitude)
    );

    if (!rows.length) {
      throw new NotFoundException('Không tìm được node gần nhất');
    }

    return rows[0].id; // chính là fid
  }

  // 🚗 Tính route từ 2 toạ độ — Đường 2 chiều
  async getRoute(
    fromLat: number,
    fromLng: number,
    toLat: number,
    toLng: number,
  ): Promise<RouteResponse> {
    // 1️⃣ Tìm nearest nodes
    const fromNodeId = await this.findNearestNodeId(fromLat, fromLng);
    const toNodeId = await this.findNearestNodeId(toLat, toLng);

    // ❗ Không chặn cùng node nữa — để pgRouting xử lý
    // if (fromNodeId === toNodeId) { ... }

    // 2️⃣ Lấy GeoJSON tuyến đường (two-way graph)
    const routeRows = await this.dataSource.query<RouteRow[]>(
      `
        WITH route AS (
          SELECT *
          FROM pgr_dijkstra(
            'SELECT fid AS id,
                    from_id AS source,
                    to_id   AS target,
                    cost,
                    cost AS reverse_cost
             FROM duong_routing'::text,
            $1::bigint,
            $2::bigint,
            false  
          )
        )
        SELECT
          ST_AsGeoJSON(
            ST_LineMerge(
              ST_Union(d.geom)
            )
          ) AS geojson,
          SUM(d.cost) AS total_cost
        FROM route r
        JOIN duong_routing d
          ON r.edge = d.fid
        WHERE r.edge <> -1;
      `,
      [fromNodeId, toNodeId],
    );

    if (!routeRows.length || !routeRows[0].geojson) {
      throw new NotFoundException(
        'Không tìm được hình dạng tuyến đường (geom)',
      );
    }

    const row = routeRows[0];
    const totalCost = row.total_cost ?? 0;

    // 3️⃣ Lấy danh sách step chi tiết
    const steps = await this.dataSource.query<StepRow[]>(
      `
        SELECT r.seq, r.node, r.edge, r.cost, r.agg_cost
        FROM pgr_dijkstra(
          'SELECT fid AS id,
                  from_id AS source,
                  to_id   AS target,
                  cost,
                  cost AS reverse_cost
           FROM duong_routing'::text,
          $1::bigint,
          $2::bigint,
          false
        ) AS r
        WHERE r.edge <> -1
        ORDER BY r.seq;
      `,
      [fromNodeId, toNodeId],
    );

    return {
      fromNodeId,
      toNodeId,
      totalCost,
      geojson: row.geojson as string,
      steps,
    };
  }

  // 🔍 (Optional) debug: lấy toàn bộ edges
  async getAllEdges(): Promise<DuongXa[]> {
    return this.duongXaRepo.find({
      take: 5000,
    });
  }
}
