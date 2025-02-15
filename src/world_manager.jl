import Base.rand

export chunk_index, chunk_center, central_chunk, chunk_range, block_state, generate_chunk

# perlin noise
sampler = perlin_2d(;seed=1)
sampler3 = perlin_3d(seed=1)
"""
    chunk_index(x::Int, z::Int)

Returns chunk Indexes based on their central value (x,z) in a world where 
chunk size is 64*64 in x and z direction

"""
function chunk_index(x::Int, z::Int)
    return ( floor(Int, x/48), floor(Int, z/48))
end

"""
    chunk_center(chunkindexX::Int, chunkindexZ::Int)

Returns chunk center based on central point of those chunks
"""
function chunk_center(chunkindexX::Int, chunkindexZ::Int)
    return (chunkindexX*48, chunkindexZ*48)
end


"""
    central_chunk(x::Int, z::Int)

Return the central_chunk location based on x, z
"""
function central_chunk(x::Int, z::Int)
    return chunk_center(floor(Int, (x+32)/64), floor(Int, (z+32)/64))
end

"""
    chunk_range(chunkindexX::Int, chunkindexZ::Int)

Return range of x and z that chunks has
"""
function chunk_range(chunkindexX::Int, chunkindexZ::Int)
    return ((chunkindexX-32):1:(chunkindexX+31),  (chunkindexZ-32):1:(chunkindexZ+31))
end

@enum BlockType begin
    air = 1
    stone = 2
    water = 3
    grass = 4
    dirt = 5
    wood = 6
    leaves = 7
    bedrock = 8
    cloud = 9

    bush = 10
    yellowflower = 11
    redflower = 12
    blueflower = 13
    sunflower = 14
    whiteflower = 15
    properblueflower = 16 

    musicbox = 17
end

"""
    tree_center(x::Int, z::Int)

Return any x,z this function tells the tree center that locations should be in
"""
function tree_center(x::Int, z::Int)
    resX = (x%16 > 1 || x%16 < -1) ? -1 : x%16
    resZ = (z%16 > 1 || z%16 < -1) ? -1 : z%16
    return x-resX, z-resZ
end

"""
    rand1(x::Int, z::Int)

Return any x,z this function returns a random number
"""
function rand1(center::Tuple)
    x, z = center
    return trunc(Int, 5*sample(sampler, x/10, z/10));
end

"""
    block_state(x::Int, y::Int, z::Int)

Return any x,y,z this function tells the block state that locations should be in
"""
function block_state(x::Int, y::Int, z::Int)
    surfaceBase = 16;
    rands = trunc(Int, 5*sample(sampler, x/10, z/10));
    surfaceY = surfaceBase + rands;

    seaLevel = 14
    if (y == surfaceY && x == 10 && z == 10)
        return BlockType(17)
    elseif (y<surfaceY)
        if (y<=-10)
            if (y<-12)
                return BlockType(8)
            elseif (y >-11)
                return BlockType(2)
            elseif (rand()>0.2)
                return BlockType(8)
            else 
                return BlockType(2)
            end
        elseif (y<8)
            b = abs(sample(sampler3, x/16, y/16,z/16))
            # if(y < -10) return BlockType(1) end
            return (b>0.2) ? BlockType(2) : BlockType(1)
        elseif (y < surfaceY - 5)
            return BlockType(2)
        elseif (y < surfaceY -3)
            return BlockType(5)
        elseif (y < surfaceY)
            return BlockType(4)
        else 
            return BlockType(1)
        end
    elseif (y< seaLevel)
        return BlockType(3)
    elseif (y>25 && y <28)
        b = abs(sample(sampler3, x/16, y/16,z/16))
        return (b>0.38) ? BlockType(9) : BlockType(1)
    else
        if (y<surfaceY+3)
            if (z%16 in [-15,-1, 0,1,15] && x%16 in [-15,-1,0,1,15])
                if (x%16 == 0 && z%16 ==0)
                    return BlockType(6)
                elseif (y > surfaceBase + rand1(tree_center(x, z)))
                    return BlockType(7)
                else
                    return BlockType(1)
                end
            elseif (rand() >0.9 && y == surfaceY)
                return BlockType(rand(10:16))
            else 
                return BlockType(1)
            end
        else
            return BlockType(1)
        end
    end
end


"""
    generate_chunk(chunkindexX::Int, chunkindexZ::Int)

Process and adds chunks blocks to database for later use.
"""
function generate_chunk(db, chunkindexX::Int, chunkindexZ::Int)
    xrange, zrange = chunk_range(chunkindexX, chunkindexZ)
    @info xrange, zrange
    yrange = 0:1:20

    write_query = DBInterface.prepare(db, "INSERT INTO chunks (sno, chunkX, chunkZ, x, y, z, blocktype) VALUES (?,?,?,?,?,?,?)") 
    snos = Vector{String}([])
    xs = Vector{Int}([])
    ys = Vector{Int}([])
    zs = Vector{Int}([])
    bls = Vector{Int}([])
    for x in xrange, y in yrange, z in zrange
        push!(snos, join([x,y,z], '-'))
        push!(xs, x)
        push!(ys, y)
        push!(zs, z)
        push!(bls, Int(block_state(x, y, z)))
    end
    @info length(snos)
    cXs = [chunkindexX for i in 1:length(snos)]
    cZs = [chunkindexZ for i in 1:length(snos)]
    table_data = (sno=snos, chunkX=cXs, chunkZ=cZs, x=xs, y=ys, z=zs, blocktype=bls)
    DBInterface.executemany(write_query, table_data) 
end


function surface_height(x::Int, z::Int)
    surfaceY = 16;
    rands = trunc(Int, 5*sample(sampler, x/10, z/10));
    surfaceY = surfaceY + rands;
    return surfaceY
end